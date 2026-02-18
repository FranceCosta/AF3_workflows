#!/usr/bin/bash -eu

INPUT_FASTA=$1
MSA_DIR=$2
PROJECT_DIR=$3
USE_ENV=$4
USE_TMPL=$5

echo "Generating MSAs using the local database"

source "${PROJECT_DIR}/.env"
export PATH="${COLABFOLD_PATH}:${PATH}"
colabfold_search $INPUT_FASTA $COLABFOLD_DB $MSA_DIR \
    --af3-json \
    --use-env "$USE_ENV" \
    --use-templates "$USE_TMPL" \
    --db2 pdb100_230517