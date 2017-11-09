require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, flatten}

export get-deps = (docs, keypath, curr-cache=[]) ->
    [arr-path, search-path] = keypath.split '.*.'
    dep-requirements = []
    docs = flatten [docs]
    for doc in docs
        #console.log "for doc: #{doc._id}, components:", doc.components

        const dep-arr = doc `get-with-keypath` arr-path
        if dep-arr and not empty dep-arr
            for index of dep-arr
                dep-name = dep-arr[index] `get-with-keypath` search-path
                dep-requirements.push dep-name unless dep-name in curr-cache
                #console.log "reported dependencies: ", dep-requirements

    return dep-requirements
