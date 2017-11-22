require! './test-utils': {make-tests}
require! './packing': {clone}
require! './merge': {merge}
require! 'prelude-ls': {Obj}

export patch-changes = (orig, changes) ->
    if typeof! changes is \Object
        orig = {} unless orig

        if changes.key and (changes.key isnt orig.key)
            # original document's attributes are invalid
            orig = changes
        else
            for role, change of changes
                if typeof! change is \Object
                    orig[role] = patch-changes orig[role], change
                else
                    orig[role] = change
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

    'deeper change patch': ->
        # no need for this
        orig =
            a: B: a: c:
                a:
                    d:
                        a: su: key: \KAY
                        key: \Pasta
                    e: key: \foo
                key: \bar

        changes =
            a: B: a: c: a: d: key: \baz

        expect patch-changes orig, changes
        .to-equal do
            a: B: a: c:
                a:
                    d:
                        key: \baz
                    e: key: \foo
                key: \bar

    'deeper change patch 2': ->
        # no need for this
        orig =
            a: B: a: c:
                a:
                    d:
                        a: su: key: \KAY
                        key: \Pasta
                    e: key: \foo
                key: \bar

        changes =
            a: B: key: \baz

        expect patch-changes orig, changes
        .to-equal do
            a: B: key: \baz
