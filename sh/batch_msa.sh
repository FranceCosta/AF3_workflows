#!/usr/bin/bash -eu

INPUT_FASTA=$1
MSA_DIR=$2
PROJECT_DIR=$3

echo "Generating MSAs using the local database"

source "${PROJECT_DIR}/.env"
export PATH="${COLABFOLD_PATH}:${PATH}"
colabfold_batch $INPUT_FASTA $MSA_DIR $COLABFOLD_DB --af3-json --data $COLAB_MODELS_DIR