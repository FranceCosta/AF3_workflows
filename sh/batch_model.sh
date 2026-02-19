#!/bin/bash -eu

# Define directories
input_dir=$1
output_dir=$2
PROJECT_DIR=$3
KEEP_ALL_PRED=$4

source "${PROJECT_DIR}/.env"

# Get list of file names (without paths)
files=("${input_dir}"/*.json)

# Get the Nth file based on SLURM_ARRAY_TASK_ID
input_file=${files[$SLURM_ARRAY_TASK_ID - 1]}
input_basename=$( basename $input_file )
echo $input_dir/$input_basename
output_name=$(grep -o '"name": *"[^"]*"' "$input_file" | sed 's/"name": *"\(.*\)"/\1/')
output_name=$(echo "$output_name" | tr -d '|:' | tr '[:upper:]' '[:lower:]')

task_output_dir="${output_dir}/${output_name}"

# Check if deprecated file exists
if find "$task_output_dir" -maxdepth 1 -name '*_model.cif' | grep -q .; then
    echo "Pre-existing folder with model found at ${task_output_dir}, skipping modelling..."
else
    # Clean potentially conflicting dir
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
fi

# Remove unnecessary files from the output
if find "$task_output_dir" -maxdepth 1 -name '*_model.cif' 2>/dev/null | grep -q .; then
    rm -f "${task_output_dir}"/*_data.json
    rm -f "${task_output_dir}/TERMS_OF_USE.md"
    # Remove all models only if required
    if [ "$KEEP_ALL_PRED" -eq 0 ]; then
        rm -rf "${task_output_dir}"/seed-*_sample-*
        rm -rf "${task_output_dir}"/ranking_scores.csv
    fi
fi