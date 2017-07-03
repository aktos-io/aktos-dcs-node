#!/bin/bash

find_scada_root () {
    local name=""
    testing_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    while :; do
        name=$(basename $testing_dir)
        if [[ "$name" == "scada.js" ]]; then
            echo $testing_dir
            return 0
        elif [[ "$name" == "/" ]]; then
            return 255
        else
            testing_dir=$(realpath "$testing_dir/..")
        fi
    done
}

SCADA=$(find_scada_root)

# change working directory
export NODE_PATH="${SCADA}/node_modules:${SCADA}/src/lib:$NODE_PATH"
