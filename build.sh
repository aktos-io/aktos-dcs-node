#!/bin/bash
DIR=$(dirname "$(readlink -f "$0")")
OUTPUT="dist/dcs.js"
echo "Bundling $OUTPUT"

# Create bundle
cd $DIR
browserify --extension .ls -t browserify-livescript browser.ls -o $OUTPUT
[[ $? == 0 ]] && echo "...build succeeded in $OUTPUT"
