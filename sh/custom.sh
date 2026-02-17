#!/usr/bin/bash -eu

INPUT_FASTA=$1
INPUT_PREFIX=$2
PROJECT_DIR=$3
source "${PROJECT_DIR}/.env"
OUTPUT_DIR="./"
TMP_DIR="tmp"

echo "Fetching MSA using ColabFold server"
export PATH="${COLABFOLD_PATH}:${PATH}"

colabfold_batch $INPUT_FASTA $TMP_DIR --af3-json --jobname-prefix $INPUT_PREFIX

echo "Running AF3 prediction"
AF3_INPUT_FILE="${INPUT_PREFIX}_0.json"

singularity exec --nv --bind ${TMP_DIR}:/root/af_input \
    --bind ${OUTPUT_DIR}:/root/af_output \
    --bind ${AF3_MODELS}:/root/models \
    --bind ${AF3_DATABASES}:/root/public_databases \
        ${AF3_SIF_FILE} \
        python $AF3_PY \
            --json_path=/root/af_input/${AF3_INPUT_FILE} \
            --model_dir=/root/models \
            --db_dir=/root/public_databases \
            --output_dir=/root/af_output

echo "Computation completed. Results available at: ${INPUT_PREFIX}"