#!/usr/bin/bash -eu

# Defaults
MAX_CONCURRENT_GPU_JOBS=5
MSA_TIME="24:00:00"
MSA_MEM="256GB"
MSA_CPUS="32"
MOD_TIME="1:00:00"
MOD_MEM="32GB"
OUTPUT_PATH=""
ADD_DNA=false
USE_ENV="1"
USE_TMPL="1"

usage() {
    echo "Usage: $(basename $0) [options] input_fasta.fa"
    echo ""
    echo "Options:"
    echo "  -h                    Show this help message"
    echo "  -o <path>             Output path prefix (default: current directory)"
    echo "  -d                    Append DNA probes for DNA binding prediction. Works with homodimers only."
    echo "  -j <int>              Max concurrent GPU jobs (default: ${MAX_CONCURRENT_GPU_JOBS})"
    echo "  -t <HH:MM:SS>         MSA time limit (default: ${MSA_TIME})"
    echo "  -m <mem>              MSA memory (default: ${MSA_MEM})"
    echo "  -T <HH:MM:SS>         Modelling time limit (default: ${MOD_TIME})"
    echo "  -M <mem>              Modelling memory (default: ${MOD_MEM})"
    echo "  -C <ncpus>            Number of CPUs for MSA generation (default: ${MSA_CPUS})"
    echo "  -E <int>              MSA generation --use-env option (default: ${USE_ENV})"
    echo "  -P <int>              MSA geneation --use-templates option (default: ${USE_TMPL})"
    exit 0
}

while getopts "hdo:j:t:m:T:M:C:E:P:" opt; do
    case $opt in
        h) usage ;;
        d) ADD_DNA=true ;;
        o) OUTPUT_PATH=$OPTARG ;;
        j) MAX_CONCURRENT_GPU_JOBS=$OPTARG ;;
        t) MSA_TIME=$OPTARG ;;
        m) MSA_MEM=$OPTARG ;;
        T) MOD_TIME=$OPTARG ;;
        M) MOD_MEM=$OPTARG ;;
        C) MSA_CPUS=$OPTARG ;;
        E) USE_ENV=$OPTARG ;;
        P) USE_TMPL=$OPTARG ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

INPUT_FASTA=${1:?Error: input fasta required. Use -h for help.}

DATE=$(date '+%Y%m%d')
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FASTA_BASENAME=$(basename "${INPUT_FASTA}" .fasta)
FASTA_BASENAME=$(basename "${FASTA_BASENAME}" .fa)
PREFIX="${DATE}_${FASTA_BASENAME}"

if [[ -n "$OUTPUT_PATH" ]]; then
    OUTPUT_DIR="${OUTPUT_PATH}/${PREFIX}_OUT"
else
    OUTPUT_DIR="${PREFIX}_OUT"
fi

MSA_DIR="${OUTPUT_DIR}/MSAs"
MOD_DIR="${OUTPUT_DIR}/af3_models"
LOG_DIR="log"
source "${PROJECT_DIR}/.env"

mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$MOD_DIR"

# Append DNA probes if -d flag is set
if [[ "$ADD_DNA" == true ]]; then
    : ${DNA_PROBE_FOR:?Error: DNA_PROBE_FOR not set in .env}
    : ${DNA_PROBE_REV:?Error: DNA_PROBE_REV not set in .env}

    DNA_FASTA="${OUTPUT_DIR}/sequences_with_dna.fa"
    echo "Appending DNA probes to sequences, saving to ${DNA_FASTA}..."

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == ">"* ]]; then
            # Validate: count colons in header (should be 1 for 2 protein chains)
            COLONS=$(echo "$line" | tr -cd ':' | wc -c)
            if (( COLONS > 1 )); then
                echo "Error: header has more than 2 protein chains: ${line}" >&2
                exit 1
            fi
            echo "${line}:dna1:dna2"
        else
            # Validate: check that the two protein chains are identical
            CHAIN1=$(echo "$line" | cut -d':' -f1)
            CHAIN2=$(echo "$line" | cut -d':' -f2)
            if [[ "$CHAIN1" != "$CHAIN2" ]]; then
                echo "Error: protein chains are not identical in sequence: ${line}" >&2
                echo "  Chain 1: ${CHAIN1}" >&2
                echo "  Chain 2: ${CHAIN2}" >&2
                exit 1
            fi
            echo "${line}:dna|${DNA_PROBE_FOR}:dna|${DNA_PROBE_REV}"
        fi
    done < "$INPUT_FASTA" > "$DNA_FASTA"

    INPUT_FASTA="$DNA_FASTA"
fi

NUM_PROT=$(grep -c ">" "$INPUT_FASTA")

# MSA
echo "Submitting MSA (N=${NUM_PROT})"
MSA_JOBID=$(
    sbatch --parsable \
        --job-name="${PREFIX}_MSA" \
        --error="$LOG_DIR/%x.err" \
        --output="$LOG_DIR/%x.out" \
        --time=$MSA_TIME \
        --mem=$MSA_MEM \
        --nodes=1 \
        --cpus-per-task=$MSA_CPUS \
        "$PROJECT_DIR/sh/batch_msa.sh" "$INPUT_FASTA" "$MSA_DIR" "$PROJECT_DIR" "$USE_ENV" "$USE_TMPL"
)
echo "MSA jobid: ${MSA_JOBID}"

# Modelling
echo "Submitting modelling (N=${NUM_PROT})"
MOD_JOBID=$(
    sbatch --parsable \
        --job-name="${PREFIX}_MOD" \
        --dependency=afterok:$MSA_JOBID \
        --array=1-$NUM_PROT%$MAX_CONCURRENT_GPU_JOBS \
        --time=$MOD_TIME \
        --mem=$MOD_MEM \
        --gres=gpu:a100:1 \
        --error="$LOG_DIR/%x_%a.err" \
        --output="$LOG_DIR/%x_%a.out" \
        "$PROJECT_DIR/sh/batch_model.sh" "$MSA_DIR" "$MOD_DIR" "$PROJECT_DIR"
)
echo "Mod jobid: ${MOD_JOBID}"

# Cleanup job - cancels MOD array if MSA fails
sbatch --job-name="${PREFIX}_CLEANUP" \
    --dependency=afternotok:$MSA_JOBID \
    --time=00:05:00 \
    --mem=100MB \
    --error="$LOG_DIR/%x.err" \
    --output="$LOG_DIR/%x.out" \
    --wrap="scancel ${MOD_JOBID}; echo 'MSA failed, cancelled modelling job ${MOD_JOBID}'" > /dev/null