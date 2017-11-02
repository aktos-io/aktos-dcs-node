require! '../../lib': {merge}

export merge-deps = (obj, dep-keypath, dep-list) ->
    if typeof! obj[dep-keypath] is \Object
        for let dep-key of obj[dep-keypath]
            dep = dep-list[dep-key]
            if typeof! dep is \Object
                # merge recursively
                dep = merge-deps dep, dep-keypath, dep-list
            obj[dep-keypath][dep-key] = dep `merge` obj[dep-keypath][dep-key]
    return obj


# ----------------------- TESTS ------------------------------------------
tests =
    'simple': ->
        test =
            doc:
                _id: 'bar'
                nice: 'day'
                deps:
                    foo: {}

            recurse:
                foo:
                    _id: 'foo'
                    hello: 'there'

        return do
            result: merge-deps test.doc, \deps, test.recurse
            expected:
                _id: 'bar'
                nice: 'day'
                deps:
                    foo:
                        _id: 'foo'
                        hello: 'there'

    'one dependency used in multiple locations': ->
        test =
            doc:
                _id: 'bar'
                nice: 'day'
                deps:
                    foo: {}

            recurse:
                foo:
                    _id: 'foo'
                    hello: 'there'
                    deps:
                        baz: {}
                        qux: {}
                baz:
                    _id: 'baz'
                    deps:
                        qux: {}
                qux:
                    _id: 'qux'
                    hello: 'world'

        return do
            result: merge-deps test.doc, \deps, test.recurse
            expected:
                _id: 'bar'
                nice: 'day'
                deps:
                    foo:
                        _id: 'foo'
                        hello: 'there'
                        deps:
                            baz:
                                _id: 'baz'
                                deps:
                                    qux:
                                        _id: 'qux'
                                        hello: 'world'
                            qux:
                                _id: 'qux'
                                hello: 'world'


    'dependencies with overwritten values': ->
        test =
            doc:
                _id: 'bar'
                nice: 'day'
                deps:
                    foo:
                        hello: 'world'

            recurse:
                foo:
                    _id: 'foo'
                    hello: 'there'
                    deps:
                        baz: {}
                        qux: {}
                baz:
                    _id: 'baz'
                    deps:
                        qux: {}
                qux:
                    _id: 'qux'
                    hello: 'world'

        return do
            result: merge-deps test.doc, \deps, test.recurse
            expected:
                _id: 'bar'
                nice: 'day'
                deps:
                    foo:
                        _id: 'foo'
                        hello: 'world'
                        deps:
                            baz:
                                _id: 'baz'
                                deps:
                                    qux:
                                        _id: 'qux'
                                        hello: 'world'
                            qux:
                                _id: 'qux'
                                hello: 'world'



for name, test of tests
    res = test!
    unless res
        console.log "Test [#{name}] is skipped..."
        continue

    try
        expected = JSON.stringify(res.expected)
        result = JSON.stringify(res.result)
        if result isnt expected
            console.error "merge-deps failed on test: #{name}"
            console.log "merged  \t: ", result
            console.log "expected\t: ", expected
        else
            console.log "merge-deps passed from test: #{name}."
    catch
        debugger
