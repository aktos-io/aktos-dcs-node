require! '../../lib': {merge, clone}
require! '../../lib/test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, flatten, Obj}

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


export merge-deps = (doc, keypath, dep-sources) ->
    if typeof! dep-sources isnt \Object
        console.warn "merge-deps: Dependency sources must be an Object, found:", dep-sources
        return doc

    if Obj.empty dep-sources
        return doc

    [arr-path, search-path] = keypath.split '.*.'
    const dep-arr = doc `get-with-keypath` arr-path

    if dep-arr and not empty dep-arr
        for index of dep-arr
            dep-name = dep-arr[index] `get-with-keypath` search-path
            if typeof! dep-sources[dep-name] is \Object
                dep-source = clone dep-sources[dep-name]
            else
                console.error "merge-deps: Required dependency is not found: ", dep-name
                return doc


            if typeof! (dep-source `get-with-keypath` arr-path) is \Array
                # merge recursively
                dep-source = merge-deps dep-source, keypath, dep-sources

            dep-arr[parse-int index] = dep-source <<< dep-arr[index]

    return doc


# ----------------------- TESTS ------------------------------------------
make-tests \merge-deps, do
    'simple': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                * key: \foo
                ...

        dependencies =
            foo:
                _id: 'foo'
                hello: 'there'

        return do
            result: merge-deps doc, \deps.*.key, dependencies
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    * key: \foo
                      _id: 'foo'
                      hello: 'there'
                    ...

    'one dependency used in multiple locations': ->
        test =
            doc:
                _id: 'bar'
                nice: 'day'
                deps:
                    * key: 'foo'
                    ...

            recurse:
                foo:
                    _id: 'foo'
                    hello: 'there'
                    deps:
                        * key: \baz
                        * key: \qux
                baz:
                    _id: 'baz'
                    deps:
                        * key: \qux
                        ...
                qux:
                    _id: 'qux'
                    hello: 'world'

        return do
            result: merge-deps test.doc, \deps.*.key , test.recurse
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                  * key: \foo
                    _id: 'foo'
                    hello: 'there'
                    deps:
                      * key: \baz
                        _id: 'baz'
                        deps:
                          * key: \qux
                            _id: 'qux'
                            hello: 'world'
                          ...
                      * key: \qux
                        _id: 'qux'
                        hello: 'world'
                    ...

    'dependencies with overwritten values': ->
        test =
            doc:
                _id: 'bar'
                nice: 'day'
                deps:
                    * key: 'foo'
                      hello: \overwritten
                    ...

            recurse:
                foo:
                    _id: 'foo'
                    hello: 'there'
                    deps:
                        * key: \baz
                        * key: \qux
                baz:
                    _id: 'baz'
                    deps:
                        * key: \qux
                        ...
                qux:
                    _id: 'qux'
                    hello: 'world'

        return do
            result: merge-deps test.doc, \deps.*.key , test.recurse
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                  * key: \foo
                    _id: 'foo'
                    hello: 'overwritten'
                    deps:
                      * key: \baz
                        _id: 'baz'
                        deps:
                          * key: \qux
                            _id: 'qux'
                            hello: 'world'
                          ...
                      * key: \qux
                        _id: 'qux'
                        hello: 'world'
                    ...
