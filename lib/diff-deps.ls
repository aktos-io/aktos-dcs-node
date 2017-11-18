require! './test-utils': {make-tests}
require! 'prelude-ls': {keys, union, Obj}

export diff-deps = (keypath, orig, curr) ->
    [arr-path, search-path] = keypath.split '.*.'

    change = {}
    unless orig
        return curr
    unless curr
        return {+deleted}

    for key in union keys(orig), keys(curr)
        orig-val = if orig => that[key] else {}
        curr-val = if curr => that[key] else {}
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

make-tests 'diff-deps', do
    'simple': ->
        orig =
          "components": {
            my1: {
                key: 'hello'
            }
          }

        _new =
          "components": {
            my1: {
                key: 'hello'
                val: 5
            }
          }


        result: diff-deps 'components.*.key', orig, _new
        expect:
            components:
                my1:
                    val: 5

    'diff when orig is null': ->
        orig =
          "components":
            my1: null

        _new =
          "components":
            my1:
                val: 5

        result: diff-deps 'components.*.key', orig, _new
        expect:
            components:
                my1:
                    val: 5

    'no difference': ->
        orig =
          "components":
            my1:
                val: 5

        _new =
          "components":
            my1:
                val: 5

        result: diff-deps 'components.*.key', orig, _new
        expect: {}

    'deleted property': ->
        orig =
          "components":
            my1:
                val: 5

        _new =
          "components":
            my1: null

        result: diff-deps 'components.*.key', orig, _new
        expect:
            components:
                my1: {"deleted":true}
