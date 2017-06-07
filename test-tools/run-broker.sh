#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR=$(realpath "$CURR_DIR/../../../..")
echo "ROOT_DIR is: $ROOT_DIR"

export NODE_PATH="${ROOT_DIR}/src/lib:$NODE_PATH"
lsc ../src/broker.ls
