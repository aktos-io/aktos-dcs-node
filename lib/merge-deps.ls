require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union}

export apply-changes = (doc, changes) ->
    changes = changes or doc.changes
    for change-path, change of changes
        if typeof! change is \Object
            if change.deleted
                delete doc[change-path]
            else
                deep-change = apply-changes doc[change-path], change
                doc[change-path] = deep-change
        else
            doc[change-path] = change
    doc

make-tests \apply-changes, do
    'simple': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
            changes:
                deps:
                    my:
                        value: 5

        return do
            result: apply-changes doc
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
                        value: 5
                changes:
                    deps:
                        my:
                            value: 5

    'simple2': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
                    deps:
                        x:
                            hello: \world
            changes:
                deps:
                    my:
                        value: 5
                        deps:
                            x:
                                hello: \there

        return do
            result: apply-changes doc
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
                        value: 5
                        deps:
                            x:
                                hello: \there
                changes:
                    deps:
                        my:
                            value: 5
                            deps:
                                x:
                                    hello: \there


    'delete example': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
                    deps:
                        x:
                            hello: \world
            changes:
                deps:
                    my:
                        value: 5
                        deps:
                            x:
                                hello: {deleted: yes}

        return do
            result: apply-changes doc
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
                        value: 5
                        deps:
                            x: {}
                changes:
                    deps:
                        my:
                            value: 5
                            deps:
                                x:
                                    hello: {deleted: yes}

class DependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, DependencyError)




export merge-deps = (doc, keypath, dep-sources={}, opts={}) ->
    [arr-path, search-path] = keypath.split '.*.'
    const dep-arr = doc `get-with-keypath` arr-path

    unless Obj.empty dep-arr
        for index of dep-arr
            dep-name = dep-arr[index] `get-with-keypath` search-path
            continue unless dep-name
            if typeof! dep-sources[dep-name] is \Object
                dep-source = clone dep-sources[dep-name]
            else
                throw new DependencyError("merge-deps: Required dependency is not found:", dep-name)

            if typeof! (dep-source `get-with-keypath` arr-path) is \Object
                # merge recursively
                dep-source = merge-deps dep-source, keypath, dep-sources, {+calc-changes}

            dep-arr[index] = dep-source <<< dep-arr[index]

    if opts.calc-changes
        return apply-changes doc
    else
        return doc

export bundle-deps = (doc, deps) ->
    return {doc, deps}

export diff-deps = (keypath, orig, curr) ->
    [arr-path, search-path] = keypath.split '.*.'

    change = {}
    for key in union keys(orig), keys(curr)
        orig-val = orig[key]
        curr-val = curr[key]
        if JSON.stringify(orig-val) isnt JSON.stringify(curr-val)
            if typeof! orig-val is \Object
                # make a recursive diff
                change[key] = {}
                for item of orig-val
                    diff = diff-deps keypath, orig-val[item], curr-val[item]
                    change[key][item] = diff
            else if typeof! orig-val is \Array
                debugger
            else
                change[key] = (curr-val or null)

    return change


# ----------------------- TESTS ------------------------------------------
make-tests \merge-deps, do
    'simple': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo

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
                    my:
                        _id: 'foo'
                        hello: 'there'
                        key: \foo

    'one dependency used in multiple locations': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my1:
                    key: 'foo'

        deps =
            foo:
                _id: 'foo'
                hello: 'there'
                deps:
                    hey:
                        key: \baz
                    hey2:
                        key: \qux
            baz:
                _id: 'baz'
                deps:
                    hey3:
                        key: \qux
            qux:
                _id: 'qux'
                hello: 'world'

        return do
            result: merge-deps doc, \deps.*.key , deps
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    my1:
                        key: \foo
                        _id: 'foo'
                        hello: 'there'
                        deps:
                            hey:
                                key: \baz
                                _id: 'baz'
                                deps:
                                    hey3:
                                        key: \qux
                                        _id: 'qux'
                                        hello: 'world'

                            hey2:
                                key: \qux
                                _id: 'qux'
                                hello: 'world'
