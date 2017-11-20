require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union}
#require! './apply-changes': {apply-changes, apply-changes2}
require! './diff-deps': {diff-deps}
require! './patch-changes': {patch-changes}

# re-export
export diff-deps
export patch-changes

export class DependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, DependencyError)

export class CircularDependencyError extends Error
    (@message, @branch) ->
        super ...
        Error.captureStackTrace(this, CircularDependencyError)

"""
Design problems for changes algorithm:
    1. Changes should be applied AFTER merging the original document with its
    dependencies in order to overwrite the changes appropriately.

    2. Changes should be applied BEFORE merging the original document, because
    a remote dependency might be changed, and subsequent changes should be applied
    after merging with the correct remote dependencies.

"""

export merge-deps = (doc, dep-path, dep-sources={}, changes={}, branch=[]) ->
    # search-path is "remote document id path" (fixed as `key`)
    # dep-path is the path where all dependencies are listed by their roles
    search-path = \key
    dep-path = dep-path.split '.*.' .0

    eff-changes = (clone <| doc.changes or {}) `merge` changes

    # any changes that involves remote documents MUST be applied before doing anything
    # for addressing Design problem #1
    for role, change of eff-changes?[dep-path]
        unless typeof! doc[dep-path][role] is \Object
            doc[dep-path][role] = {}
        doc[dep-path][role] `merge` change

    missing-deps = []
    if typeof! doc[dep-path] is \Object
        for role, dep of doc[dep-path] when dep.key?
            # Report missing dependencies
            unless dep.key of dep-sources
                missing-deps.push dep.key
                continue

            dep-changes = eff-changes?[dep-path]?[role]

            # detect any circular references
            branch.push dep.key
            #console.log "branch: ", branch
            if branch.length isnt unique(branch).length
                throw new CircularDependencyError "merge-deps: Circular dependency is not allowed", branch

            b = branch.length
            # if dependency-source has further dependencies, merge them first
            try
                dep-source = merge-deps (clone dep-sources[dep.key]), dep-path, dep-sources, dep-changes, branch
            catch
                if e.dependency
                    # bubble up the missing dependencies of dependencies
                    missing-deps = union missing-deps, that
                    continue
                else
                    throw e

            if branch.length is b
                #console.log "this seems branch end: ", branch
                branch.splice(0, branch.length)

            doc[dep-path][role] = dep-source `merge` dep

    unless empty missing-deps
        throw new DependencyError("merge-deps: Required dependency is not found", missing-deps)

    # TODO: below clone is mandatory for preventing messing up the original dep-sources
    # Prepare a test case for this.
    return clone doc


export bundle-deps = (doc, deps) ->
    return {doc, deps}

export patch-changes = (diff, changes) ->
    return diff unless changes

    if \key of diff
        changes.components = {}
        console.log "key changed, removed changes.components: #{JSON.stringify changes}"

    for k, v of diff
        if typeof! v is \Object
            v = patch-changes v, changes[k]
        changes[k] = v

    changes

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

    'simple with modified deep change': ->
        doc =
            nice: 'day'
            deps:
                my:
                    key: \bar
            changes:
                deps:
                    my:
                        key: \foo

        dependencies =
            foo:
                hello: 'there'
                deps:
                    x:
                        key: \how
                changes:
                    deps:
                        x:
                            key: \hey
                            amount: 5
            hey:
                thisis: \hey

        expect merge-deps doc, \deps.*.key, dependencies
        .to-equal do
            nice: 'day'
            deps:
                my:
                    hello: 'there'
                    key: \foo
                    deps:
                        x:
                            key: \hey
                            thisis: \hey
                            amount: 5
                    changes:
                        deps:
                            x:
                                key: \hey
                                amount: 5

            changes: clone doc.changes

    'deleted master change': ->
        return false
        doc =
            nice: 'day'
            deps:
                my:
                    key: \bar
            changes:
                deps:
                    my:
                        key: \foo
                        deps: {+deleted}

        dependencies =
            foo:
                hello: 'there'
                deps:
                    x:
                        key: \how
                changes:
                    deps:
                        x:
                            key: \hey
                            amount: 5
            hey:
                thisis: \hey

            nice:
                very: \well

        expect merge-deps doc, \deps.*.key, dependencies
        .to-equal do
            nice: 'day'
            deps:
                my:
                    hello: 'there'
                    key: \foo
                    changes:
                        key: \foo
                        deps:
                            deleted: true
                            x:
                                key: \hey
                                amount: 5
                    deps:
                        deleted: true

            changes: clone doc.changes



    'simple with modified deeper remote change': ->
        doc =
            nice: 'day'
            deps:
                my:
                    key: \bar
            changes:
                deps:
                    my:
                        key: \foo
                        deps:
                            x:
                                key: \nice

        dependencies =
            foo:
                hello: 'there'
                deps:
                    x:
                        key: \how
                changes:
                    deps:
                        x:
                            key: \hey
                            amount: 5
            hey:
                thisis: \hey

            nice:
                very: \well

        expect merge-deps doc, \deps.*.key, dependencies
        .to-equal do
            nice: 'day'
            deps:
                my:
                    hello: 'there'
                    key: \foo
                    deps:
                        x:
                            key: \nice
                            very: \well
                            amount: 5
                    changes: clone dependencies.foo.changes
            changes: clone doc.changes


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
                hey:
                    there: \hello

            changes: clone doc.changes


    'one dependency used in multiple locations plus empty changes': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my123:
                    key: 'foo'
            changes:
                deps:
                    my123: {}

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
                my123:
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
            changes: clone doc.changes

    'circular dependency': ->
        doc =
            deps:
                my:
                    key: 'foo'

        deps =
            foo:
                deps:
                    hey:
                        key: \foo

        expect (-> merge-deps doc, \deps.*.key, deps)
        .to-throw "merge-deps: Circular dependency is not allowed"

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
        .to-throw "merge-deps: Required dependency is not found"


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
