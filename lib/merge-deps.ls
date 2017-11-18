require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union}
#require! './apply-changes': {apply-changes, apply-changes2}
require! './diff-deps': {diff-deps}

# re-export
export apply-changes = ->
    debugger

export diff-deps

export class DependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, DependencyError)

export class CircularDependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, CircularDependencyError)

"""
Problem:
    1. Changes should be applied AFTER merging the original document with its
    dependencies in order to overwrite the changes appropriately.

    2. Changes should be applied BEFORE merging the original document, because
    a remote dependency might be changed, and subsequent changes should be applied
    after merging with the correct remote dependencies.

"""

export merge-deps = (doc, dep-path, dep-sources={}, changes={}) ->
    # dep-path is the path where all dependencies are listed by their roles
    # search-path is "remote document id path" (fixed as `key`)
    dep-path = dep-path.split '.*.' .0

    """
    if \bar666 of dep-sources
        debugger
    """

    try
        eff-changes = (clone <| doc.changes or {}) `merge` changes
    catch
        debugger

    # any changes that involves remote documents MUST be applied before doing anything
    for role, change of eff-changes?[dep-path]
        if role of doc[dep-path]
            # discard roles that are found in the changes but not in the
            # original document
            for x of change when x isnt \changes
                doc[dep-path][role][x] = change[x]

    if typeof! doc[dep-path] is \Object
        for role, dep of doc[dep-path] when dep.key?
            # Report missing dependencies
            # TODO: optimize this to report all missing dependencies at once
            unless dep.key of dep-sources
                throw new DependencyError("merge-deps: Required dependency is not found:", dep.key)

            dep-changes = eff-changes?[dep-path]?[role]

            # if dependency-source has further dependencies, merge them first
            dep-source = merge-deps dep-sources[dep.key], dep-path, dep-sources, dep-changes

            try
                doc[dep-path][role] = dep-source `merge` dep
            catch
                debugger

    return doc


export bundle-deps = (doc, deps) ->
    return {doc, deps}

export patch-changes = (diff, changes) ->
    return diff unless changes

    for k, v of diff
        if typeof! v is \Object
            v = patch-changes v, changes[k]
        changes[k] = v

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

        expect merge-deps doc, \deps.*.key, dependencies
        .to-equal do
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

        expect merge-deps (clone doc), \deps.*.key, dependencies
        .to-equal do
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

        expect merge-deps doc, \deps.*.key , deps
        .to-equal do
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
                    my:
                        hi: \world

        dependencies =
            foo:
                _id: 'foo'
                hello: 'there'
                deps:
                    my1:
                        key: \foo-dep
            'foo-dep':
                _id: 'foo-dep'
                eating: 'seed'

        expect merge-deps (clone doc), \deps.*.key, dependencies
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
                    _id: 'foo'
                    hello: 'there'
                    hi: \world
                    deps:
                        my1:
                            key: \foo-dep
                            _id: 'foo-dep'
                            eating: 'seed'
            changes:
                deps:
                    my:
                        hi: \world


        # change a remote dependency in the tree
        doc.changes.deps.my.key = 'roadrunner'

        # add this dependency to the dependency sources
        dependencies.roadrunner =
            _id: 'roadrunner'
            its: 'working'
            deps:
                my1:
                    key: 'coyote'
                    value: 3

        dependencies.coyote =
            _id: 'coyote'
            name: 'coyote who runs behind roadrunner'

        # just to be sure that changes are correct
        expect doc.changes.deps.my
        .to-equal do
            hi: \world
            key: \roadrunner

        expect merge-deps doc, \deps.*.key, dependencies
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: 'roadrunner'
                    _id: 'roadrunner'
                    its: 'working'
                    hi: \world
                    deps:
                        my1:
                            key: 'coyote'
                            value: 3
                            _id: 'coyote'
                            name: 'coyote who runs behind roadrunner'
            changes:
                deps:
                    my:
                        key: 'roadrunner'
                        hi: \world

    'changed remote document (2)': ->
        input =
            components:
                foo:
                    key: \bar444
            changes:
                components:
                    foo:
                        key: \bar111
                        components:
                            bar333:
                                value: null

        deps =
            bar111:
                components:
                    bar333:
                        key: \bar333
                changes:
                    components:
                        bar333:
                            amount: 30
            bar333:
                components:
                    bar555:
                        key: \Co2
                    bar666:
                        key: \bar666
                changes:
                    components:
                        bar555:
                            amount: 0.00001
                        bar666:
                            amount: 3
            Co2:
                components: {}
            bar666:
                components: {}


        expect merge-deps input, \components.*.key, deps
        .to-equal do
            components:
                foo:
                    key: \bar111
                    components:
                        bar333:
                            key: \bar333
                            amount: 30
                            value: null

                            components:
                                bar555:
                                    key: \Co2
                                    components: {}
                                    amount: 0.00001

                                bar666:
                                    key: \bar666
                                    components: {}
                                    amount: 3

                            changes:
                                components:
                                    bar555:
                                        amount: 0.00001
                                    bar666:
                                        amount: 3
                    changes:
                        components:
                            bar333:
                                amount: 30
            changes:
                components:
                    foo:
                        key: \bar111
                        components:
                            bar333:
                                value: null
