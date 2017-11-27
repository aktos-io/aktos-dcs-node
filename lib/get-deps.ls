require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {Obj, union}

export get-deps = (doc, keypath="components.*.key", requirements=[]) ->
    [dep-path, search-key] = keypath.split '.*.'

    for role, dep of doc[dep-path]
        if dep?.key
            requirements.push dep.key unless dep.key in requirements
        if typeof! dep[dep-path] is \Object
            requirements = union requirements, get-deps(dep, keypath, requirements)

    return requirements
