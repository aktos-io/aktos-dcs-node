require! './test-utils': {make-tests}
require! './packing': {clone}

export patch-changes = (orig, changes, opts={}) ->
    return orig unless changes

    if typeof! changes is \Object
        orig = {} unless orig

        if \key of changes
            #console.log "key changed, mark orig.components as deleted/invalid"
            unless opts.onlyKeys
                try delete orig.components

        for k, change of changes
            orig[k] = {} unless orig[k]

            if typeof! change is \Object
                if not change.deleted or opts.onlyKeys
                    change = patch-changes orig[k], change
            orig[k] = change
    else
        debugger

    orig

make-tests \patch-changes, do
    'changed key will invalidate the further component changes': ->
        orig =
            components:
                my:
                    key: 'hey'
                    components:
                        your:
                            key: 'how'

        changes =
            components:
                my:
                    key: 'x'
                    val: 5

        expect patch-changes orig, changes
        .to-equal do
            components:
                my:
                    key: 'x'
                    val: 5

    "changed key's components will do effect": ->
        orig =
            components:
                my:
                    key: 'hey'
                    components:
                        your:                   # this item will be deleted because {{a>}}
                            key: 'how'

        changes =
            components:
                my:
                    key: 'x'                    # {{>a}} this key is changed.
                    val: 5
                    components:
                        a:
                            the: \end

        expect patch-changes orig, changes
        .to-equal do
            components:
                my:
                    key: 'x'
                    val: 5
                    components:
                        a:
                            the: \end
