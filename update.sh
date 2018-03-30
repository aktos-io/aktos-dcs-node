#!/bin/bash

DIR=$(dirname "$(readlink -f "$0")")

cd $DIR
git pull
git submodule update --recursive --init

if [[ "$1" == "--all" ]]; then
    echo "Installing required modules:"
    ./install-modules.sh
fi 
