require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {Obj, flatten}

export get-deps = (docs, keypath, curr-cache=[]) ->
    [arr-path, search-path] = keypath.split '.*.'
    dep-requirements = []
    docs = flatten [docs]
    for doc in docs
        #console.log "for doc: #{doc._id}, components:", doc.components

        const dep-arr = doc `get-with-keypath` arr-path
        unless Obj.empty dep-arr
            for index of dep-arr
                dep-name = dep-arr[index] `get-with-keypath` search-path
                if dep-name and dep-name not in curr-cache
                    dep-requirements.push dep-name 
                #console.log "reported dependencies: ", dep-requirements

    return dep-requirements
