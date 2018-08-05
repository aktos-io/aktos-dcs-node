#!/bin/bash
set -eu -o pipefail
set_dir(){ _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; }; set_dir
safe_source () { source $1; set_dir; }
# end of bash boilerplate

OUTPUT="dist/dcs.js"
echo "Bundling $OUTPUT"

# Create bundle
cd $_dir
browserify --extension .ls -t browserify-livescript browser.ls -o $OUTPUT
[[ $? == 0 ]] && echo "...build succeeded in $OUTPUT"
