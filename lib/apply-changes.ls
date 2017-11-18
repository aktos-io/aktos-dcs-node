require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union, first}

"""
apply-changes function MUST be recursive, because root changes may contain
any level of deep changes

"""

export apply-changes2 = (doc, ) ->
    if typeof! doc isnt \Object
        throw new Error('Document should be an object')

    reapply = no
    unless role-keypath
        role-keypath = doc.changes |> keys |> first

    changes = clone <| changes or doc.changes or {}
    # If `key` will be changed, then remote document will be changed.
    # Change the key only, stop applying changes here, return the current
    # object, mark as "needs continue (reapplying)".



    for change-path, change of changes
        # change might be:
        # * a simple value
        # * a delete command (`{delete: true}`)
        # * an invalid value to be discarded (a role that doesn't exist in the role-keypath now)
        if typeof! change is \Object
            if change-path is role-keypath
                # discard invalid roles' changes
                for i of change
                    delete change[i] unless i of doc[role-keypath]

            if change.deleted
                delete doc[change-path]
            else
                [deep-change, reapply2] = apply-changes2 doc[change-path], change, role-keypath
                reapply = reapply or reapply2
                doc[change-path] = deep-change
        else
            if doc[change-path] isnt change
                console.log "change is directly assigned: #{change}"
                if change-path is \key
                    reapply = yes
                doc[change-path] = change

    [doc, reapply]


export apply-changes = (doc, changes) ->
    while true
        [doc, reapply] = apply-changes2 doc, changes
        break unless reapply
        debugger
        console.log "..............reapplying..."
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

        expect apply-changes doc
        .to-equal doc=
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

    'with extra changes': ->
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
                    your:
                        key: \there

        expect apply-changes doc
        .to-equal doc =
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
                    your:
                        key: \there

    'with no original dependencies': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps: {}
            changes:
                deps:
                    my:
                        value: 5
                    your:
                        key: \there

        expect apply-changes doc
        .to-equal doc =
            _id: 'bar'
            nice: 'day'
            deps: {}
            changes:
                deps:
                    my:
                        value: 5
                    your:
                        key: \there

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

        expect apply-changes doc
        .to-equal doc =
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
