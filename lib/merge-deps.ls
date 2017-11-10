require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find}

export merge-deps = (doc, keypath, dep-sources={}) ->
    [arr-path, search-path] = keypath.split '.*.'
    const dep-arr = doc `get-with-keypath` arr-path

    if dep-arr and not empty dep-arr
        for index of dep-arr
            dep-name = dep-arr[index] `get-with-keypath` search-path
            if typeof! dep-sources[dep-name] is \Object
                dep-source = clone dep-sources[dep-name]
            else
                throw "merge-deps: Required dependency is not found: #{dep-name}"

            if typeof! (dep-source `get-with-keypath` arr-path) is \Array
                # merge recursively
                dep-source = merge-deps dep-source, keypath, dep-sources

            dep-arr[parse-int index] = dep-source <<< dep-arr[index]

    return doc

export bundle-deps = (doc, deps) ->
    return {doc, deps}

export diff-deps = (keypath, orig, curr) ->
    [arr-path, search-path] = keypath.split '.*.'
    const dep-arr = orig `get-with-keypath` arr-path

    change = {}
    for key in unique (keys(orig) ++ keys(curr))
        orig-val = orig[key]
        curr-val = curr[key]
        if JSON.stringify(orig-val) isnt JSON.stringify(curr-val)
            if typeof! orig-val is \Array
                # make a recursive diff
                change[key] = []
                for item of orig-val
                    diff = diff-deps keypath, orig-val[item], curr-val[item]
                    change[key].push diff
            else if typeof! orig-val is \Object
                debugger
            else
                change[key] = (curr-val or null)

    unless Obj.empty change
        change[search-path] = orig[search-path]

    return change

export apply-changes = (dep-keypath, changes-keypath, doc) ->
    [arr-path, search-path] = dep-keypath.split '.*.'
    if doc
        if doc[changes-keypath]
            changes = that
            for ckey of doc
                if ckey of changes
                    # if there is a change for this
                    if ckey is arr-path
                        dep-arr = doc[arr-path]
                        throw 'This should be an array' if typeof! dep-arr isnt \Array
                        # merge recursively by "search-path"
                        for index of dep-arr
                            dep = dep-arr[index]
                            if find (.[search-path] is dep[search-path]), changes[arr-path]
                                change = that
                                tmp = JSON.parse JSON.stringify dep
                                tmp[changes-keypath] = change
                                console.log "merge recursive because ckey: #{ckey}", "tmp doc: ", tmp
                                x = apply-changes dep-keypath, changes-keypath, tmp
                                delete x[changes-keypath]
                                doc[arr-path][index] = x
                    else
                        doc[ckey] = changes[ckey]
    doc


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
