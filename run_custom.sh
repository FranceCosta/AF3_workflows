#!/usr/bin/bash -eu

# Usage: bash run_custom.sh input_fasta.sh
# Where the fasta file should be set as shown in the example
# >Complex1|Prot1:Prot2:dna_for:dna_rev
# FIRSTPROTEIN:FIRSTPROTEIN:dna|ACGT:dna|TGCA

INPUT_FASTA=$1

DATE=$(date '+%Y%m%d_%H%M')
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FASTA_BASENAME=$(basename "${INPUT_FASTA}" .fasta)
FASTA_BASENAME=$(basename "${FASTA_BASENAME}" .fa)
PREFIX="${DATE}_${FASTA_BASENAME}"
LOG_DIR="log"
source ${PROJECT_DIR}/.env

mkdir -p $LOG_DIR

echo "Submitting job ${PREFIX}"

sbatch --job-name=$PREFIX \
       --time=1:00:00 \
       --mem=32GB \
       --gres=gpu:a100:1 \
       --output=${LOG_DIR}/%x.out \
       --error=${LOG_DIR}/%x.err \
       ${PROJECT_DIR}/sh/custom.sh $INPUT_FASTA $PREFIX $PROJECT_DIR