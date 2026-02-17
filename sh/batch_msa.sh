#!/usr/bin/bash -eu

INPUT_FASTA=$1
MSA_DIR=$2
PROJECT_DIR=$3

echo "Generating MSAs using the local database"

source "${PROJECT_DIR}/.env"
export PATH="${COLABFOLD_PATH}:${PATH}"
colabfold_search $INPUT_FASTA $COLABFOLD_DB $MSA_DIR --af3-json --use-templates 1