require! './test-utils': {make-tests}

export get-with-keypath = (obj, keypath) ->
    res = obj
    if keypath
        for k in keypath.split '.'
            res = try
                res[k]
            catch
                null
    return res

make-tests \get-with-keypath, do
    'simple': ->
        obj =
            foo:
                bar:
                    baz: 2
                    hey: 3
                hello: \world

        return do
            result: obj `get-with-keypath` \foo
            expect:
                bar:
                    baz: 2
                    hey: 3
                hello: \world

    'deep': ->
        obj =
            foo:
                bar:
                    baz: 2
                    hey: 3
                hello: \world

        return do
            result: obj `get-with-keypath` \foo.bar
            expect:
                baz: 2
                hey: 3

    'deep2': ->
        obj =
            foo:
                bar:
                    baz: 2
                    hey: 3
                hello: \world

        return do
            result: obj `get-with-keypath` \foo.bar.baz
            expect: 2


    'null returns original object': ->
        obj =
            foo:
                bar:
                    baz: 2
                    hey: 3
                hello: \world

        return do
            result: obj `get-with-keypath` null
            expect: obj
