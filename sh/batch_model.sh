#!/bin/bash -eu

# Define directories
input_dir=$1
output_dir=$2
PROJECT_DIR=$3
source "${PROJECT_DIR}/.env"

# Get list of file names (without paths)
files=($(ls -1 "${input_dir}/*.json"))

# Get the Nth file based on SLURM_ARRAY_TASK_ID
input_file=${files[$SLURM_ARRAY_TASK_ID - 1]}
input_basename=$(basename "$input_file")

task_output_dir="${output_dir}/$(basename "$input_basename" .json | tr '[:upper:]' '[:lower:]')"

# Check if deprecated file exists
if find "$task_output_dir" -maxdepth 1 -name '*_model.cif' | grep -q .; then
    echo "Pre-existing folder with model found at ${task_output_dir}, skipping modelling..."
else
    rm -rf $task_output_dir
    # Run AlphaFold3
    singularity exec --nv \
        --bind "${input_dir}:/root/af_input" \
        --bind "${output_dir}:/root/af_output" \
        --bind "${AF3_MODELS}:/root/models" \
        --bind "${AF3_DATABASES}:/root/public_databases" \
        "${AF3_SIF_FILE}" \
        python "$AF3_PY" \
            --json_path="/root/af_input/${input_basename}" \
            --model_dir=/root/models \
            --db_dir=/root/public_databases \
            --output_dir=/root/af_output

    # Remove unnecessary files from the output
    if find "$task_output_dir" -maxdepth 1 -name '*_model.cif' 2>/dev/null | grep -q .; then
fi