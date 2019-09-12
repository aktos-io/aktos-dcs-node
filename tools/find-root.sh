find_DCS_root () {
    local name=""
    testing_dir=$1
    while :; do
        name=$(basename $testing_dir)
        ls "$testing_dir/dcs" > /dev/null 2>&1
        if [[ "$?" == "0" ]]; then
            echo "$testing_dir/dcs"
            return 0
        elif [[ "$name" == "dcs" ]]; then
            echo $testing_dir
            return 0
        elif [[ "$name" == "/" ]]; then
            return 255
        else
            testing_dir=$(realpath "$testing_dir/..")
        fi
    done
}

filename=$1

if [[ ! -f $filename ]]; then
    echo "First argument should be a file to run."
    exit 255
fi

base_dir=$(dirname $filename)
#echo "DEBUG: Base Dir: $base_dir"

DCS_DIR=$(find_DCS_root $base_dir)

if [[ -d $DCS_DIR ]]; then
    #echo "DEBUG: found scada root: $DCS_DIR"
    DCS_MODULES="${DCS_DIR}/lib"
    PROJECT_PATH=$(realpath "${DCS_DIR}/..")

    echo "DCS project path: ${PROJECT_PATH}"

    FOUND_MODULES=
    # add every `node_modules` into the path
    while IFS= read -r module; do
        #echo "++++++++++ adding path: $module"
        FOUND_MODULES="${FOUND_MODULES}:$module"
    done < <(find $PROJECT_PATH -type d -name "node_modules" | grep -v "node_modules\/" )
fi

export NODE_PATH="${DCS_MODULES}:${FOUND_MODULES}:${NODE_PATH:-}:${PROJECT_PATH}"
