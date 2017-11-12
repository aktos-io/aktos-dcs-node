require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union}

export apply-changes = (doc, changes) ->
    if typeof! doc is \Object
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

        return do
            result: apply-changes doc
            expect:
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
