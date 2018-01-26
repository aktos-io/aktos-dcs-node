require! './test-utils': {make-tests}
require! 'prelude-ls': {keys, union, Obj}

clean-obj = (obj) ->
    for key of obj
        # WARNING: Changing below list (undefined, null) will effect
        # the cleanup of former values (+dependencies) when key is changed
        if typeof! obj[key] in <[ Undefined Null ]>
            delete obj[key]

        if typeof! obj[key] is \Object
            obj[key] = clean-obj obj[key]
            if Obj.empty obj[key]
                delete obj[key]
    return obj

export class DiffError extends Error
    (@message) ->
        super ...
        Error.captureStackTrace(this, DiffError)


export diff-deps = (keypath, orig, curr) ->
    [arr-path, search-path] = keypath.split '.*.'

    change = {}
    unless orig
        return clean-obj curr
    unless curr
        return {+deleted}

    if orig is curr
        return null

    if (typeof! orig isnt \Object) or (typeof! curr isnt \Object)
        console.error "orig: ", orig, "curr: ", curr
        throw new DiffError "Parties must be Object type"

    for key in union keys(orig), keys(curr)
        if key.substr(-2) is '__'
            # skip any key ending with double underscore ("__")
            continue
        if key is \changes
            # skip "changes" key
            continue
        if key.char-at(0) is '_'
            # skip special keys of couchdb
            continue

        orig-val = if orig => that[key] else {}
        curr-val = if curr => that[key] else {}
        if typeof! orig-val is \Object
            # make a recursive diff
            change[key] = {}

            for item of orig-val
                diff = diff-deps keypath, orig-val[item], curr-val[item]
                change[key][item] = diff

        else if typeof! orig-val is \Array
            #console.log "...we were not expecting an array here:", orig-val
            #debugger
            null
        else
            if curr-val isnt orig-val
                change[key] = curr-val

    return clean-obj change

make-tests 'diff-deps', do
    'simple value change': ->
        orig =
            components:
                my1:
                    key: \hello

        _new =
            components:
                my1:
                    key: \hello
                    val: 5

        expect diff-deps 'components.*.key', orig, _new
        .to-equal do
            components:
                my1:
                    val: 5

    'simple key change': ->
        orig =
            components:
                my1:
                    key: \hello

        _new =
            components:
                my1:
                    key: \hey

        expect diff-deps 'components.*.key', orig, _new
        .to-equal do
            components:
                my1:
                    key: \hey

    'diff when orig is null': ->
        orig =
          "components":
            my1: null

        _new =
          "components":
            my1:
                val: 5

        expect diff-deps 'components.*.key', orig, _new
        .to-equal do
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

        expect diff-deps 'components.*.key', orig, _new
        .to-equal {}

    'deleted property': ->
        orig =
          "components":
            my1:
                val: 5

        _new =
          "components":
            my1: null

        expect diff-deps 'components.*.key', orig, _new
        .to-equal do
            components:
                my1: {"deleted":true}


    'modified deeper key': ->
        orig =
            components:
                my:
                    key: \foo
                    components:
                        my1:
                            key: \bar
                        my2:
                            hey: \there

        _new =
            components:
                my:
                    key: \taz
                    components:
                        my1:
                            key: \baz
                        my2:
                            hey: \there

        expect diff-deps 'components.*.key', orig, _new
        .to-equal do
            components:
                my:
                    key: \taz
                    components:
                        my1:
                            key: \baz
