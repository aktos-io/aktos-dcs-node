require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union}
require! './apply-changes': {apply-changes}
require! './diff-deps': {diff-deps}

# re-export
export apply-changes
export diff-deps

export class DependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, DependencyError)

export class CircularDependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, CircularDependencyError)



export merge-deps = (doc, keypath, dep-sources={}, opts={}) ->
    [arr-path, search-path] = keypath.split '.*.'
    const dep-arr = doc `get-with-keypath` arr-path

    unless Obj.empty dep-arr
        for index of dep-arr
            dep-name = dep-arr[index] `get-with-keypath` search-path
            continue unless dep-name

            # this key-value pair has further dependencies
            if typeof! dep-sources[dep-name] is \Object
                dep-source = if dep-sources[dep-name]
                    clone that
                else
                    {}
            else
                throw new DependencyError("merge-deps: Required dependency is not found:", dep-name)

            if typeof! (dep-source `get-with-keypath` arr-path) is \Object
                # if dependency-source has further dependencies,
                # merge recursively
                dep-source = merge-deps dep-source, keypath, dep-sources, {+calc-changes}

            # we have fully populated dependency-source here.


            for k of dep-arr[index]
                if k of dep-source
                    dep-arr[index]
            dep-arr[index] = dep-source <<< dep-arr[index]

    if opts.calc-changes
        return apply-changes doc
    else
        return doc

export bundle-deps = (doc, deps) ->
    return {doc, deps}


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

    'simple with extra changes': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
            changes:
                deps:
                    hey:
                        there: \hello

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

                changes:
                    deps:
                        hey:
                            there: \hello


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
    'circular dependency': ->
        return false

    'missing dependency': ->
        doc =
            deps:
                my:
                    key: \foo

        dependencies =
            bar:
                _id: 'bar'
                hello: 'there'

        expect (-> merge-deps doc, \deps.*.key, dependencies)
            .to-throw "merge-deps: Required dependency is not found:"



    'changed remote document': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
            changes:
                deps:
                    hey:
                        there: \hello

        dependencies =
            foo:
                _id: 'foo'
                hello: 'there'

        merged = merge-deps doc, \deps.*.key, dependencies

        merged.deps.my.key = "baz"
        merged.changes.deps.my = {key: 'baz'}

        dependencies.baz =
            _id: 'baz'
            its: 'working'

        expect merge-deps merged, \deps.*.key, dependencies
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: 'baz'
                    _id: 'baz'
                    its: 'working'

            changes:
                deps:
                    hey:
                        there: \hello
                    my:
                        key: 'bar'
