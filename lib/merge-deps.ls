require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union}
#require! './apply-changes': {apply-changes, apply-changes2}
require! './diff-deps': {diff-deps}
require! './patch-changes': {patch-changes}
require! './get-deps': {get-deps}

require! \jsondiffpatch

# re-export
export diff-deps
export patch-changes
export get-deps

export class DependencyError extends Error
    (@message, @dependency) ->
        super ...
        # below line causes firefox to fail from exception tests
        #Error.captureStackTrace(this, DependencyError)

export class CircularDependencyError extends Error
    (@message, @branch) ->
        super ...
        # below line causes firefox to fail from exception tests
        #Error.captureStackTrace(this, CircularDependencyError)

"""
Design challenges for the changes algorithm:

    1. Chicken/egg problem:

        1. Changes should be applied AFTER merging the original document with its
        dependencies in order to overwrite the changes appropriately.

        2. Changes should be applied BEFORE merging the original document, because
        a remote dependency might be changed, and subsequent changes should be applied
        after merging with the correct remote dependencies.
"""

dump = (desc, obj) ->
    if typeof! desc is \Object
        obj = desc
        desc = 'obj :'
    console.log desc, JSON.stringify(obj)


cleanup-deleted = (obj) ->
    if typeof! obj is \Object
        for k, v of obj
            if k is \changes
                continue
            else if v?.deleted
                delete obj[k]
            else if typeof! v is \Object
                cleanup-deleted obj[k]
    return obj

export merge-deps = (doc-id, dep-sources={}, opts={}, superior-changes={}, branch=[]) ->
    """
    opts:
        remote-doc: remote document id (default: "key")
        dep-path: dependency path (default: "components")
        changes: document changes (default: doc.changes)

    """
    # search-path is "remote document id path" (fixed as `key`)
    # dep-path is the path where all dependencies are listed by their roles
    search-path = opts.search-path or \key
    dep-path = opts.dep-path or \components
    missing-deps = []

    if typeof! doc-id is \String
        # detect any circular references
        #console.log "branch: ", branch, ", adding #{doc-id}"
        if doc-id in branch
            throw new CircularDependencyError "merge-deps: Circular dependency is not allowed", doc-id
        else
            branch.push doc-id

        if dep-sources[doc-id]
            doc-id = that
        else
            missing-deps.push doc-id


    if typeof! doc-id is \Object
        # FIXME: change `doc` with `merged`
        doc = clone doc-id
        own-changes = opts.changes or doc.changes or {}
        eff-changes = (clone own-changes) `merge` superior-changes

        /*
        # Debug outputs
        # Any changes that involves remote documents MUST be applied before doing anything
        # for addressing Design problem #1
        console.log "-------------------------------------------------"
        dump 'parent changes: ', superior-changes
        dump 'own changes: ', own-changes
        dump 'eff-changes: ', eff-changes
        # End of debug outputs */

        for role, eff-change of eff-changes[dep-path]
            #dump "eff-change is: ", eff-change
            if (typeof! eff-change is \Object) and (\key of eff-change)
                # there is a key change, decide whether we are invalidating rest of the changes
                parent = (try superior-changes[dep-path][role]) or {}
                own = (try own-changes[dep-path][role]) or {}
                if own.key isnt eff-change.key
                    #console.log "--------.invalidating all other attributes"
                    make-like-parent = (eff-change, parent) ->
                        for k of eff-change when k isnt \key
                            unless k of parent
                                #console.log "...deleting {#{k}:#{JSON.stringify(eff-change[k])}}"
                                delete eff-change[k]
                            else if typeof! parent[k] is \Object
                                make-like-parent eff-change[k], parent[k]

                    make-like-parent eff-change, parent

                doc[dep-path] = {} unless doc[dep-path]
                doc[dep-path][role] = eff-change
            else
                if typeof! doc[dep-path][role] is \Object
                    doc[dep-path][role] = patch-changes doc[dep-path][role], eff-change
                else
                    doc[dep-path][role] = eff-change

        #dump "merged (ready to merge with deps): ", doc

        if typeof! doc?[dep-path] is \Object
            #console.log "branch so far: ", JSON.stringify(branch)
            branch-so-far = clone branch
            for role, dep of doc[dep-path] when dep?key?
                # if dependency-source has further dependencies, merge them first
                dep-changes = eff-changes?[dep-path]?[role]
                unless dep.key of dep-sources
                    # Report missing dependencies
                    missing-deps.push dep.key
                    continue
                branch = clone branch-so-far
                try
                    dep-source = merge-deps dep.key, dep-sources,
                        {dep-path: opts.dep-path, search-path: opts.search-path},
                        dep-changes, branch
                catch
                    if e instanceof DependencyError
                        # bubble up the missing dependencies of dependencies
                        missing-deps = union missing-deps, e.dependency
                        continue
                    else
                        throw e

                # merge remote dependency
                doc[dep-path][role] = dep-source `merge` dep

    unless empty missing-deps
        str = missing-deps.join ', '
        throw new DependencyError("merge-deps: Required dependencies are not found: #{str}", unique(missing-deps))

    # TODO: below clone is mandatory for preventing messing up the original dep-sources
    # Prepare a test case for this.
    return clone cleanup-deleted doc


# ----------------------- TESTS ------------------------------------------
make-tests \merge-deps, do
    'deleted a simple sub property': ->
        docs =
            bar:
                nice: 'day'
                deps:
                    my:
                        prop: \foo
                    your:
                        hello: \there
                changes:
                    deps:
                        my: {+deleted}

        expect merge-deps \bar, docs, {dep-path: \deps}
        .to-equal do
            nice: 'day'
            deps:
                your:
                    hello: \there
            changes: clone docs.bar.changes

    'deleted a deep simple sub property': ->
        docs =
            bar:
                nice: 'day'
                deps:
                    my:
                        prop: \foo
                        deps:
                            tmp:
                                x: \y
                                z: \t
                                deps:
                                    j:
                                        m: \m
                    your:
                        hello: \there
                changes:
                    deps:
                        my:
                            deps:
                                tmp:
                                    deps:
                                        j: {+deleted}

        expect merge-deps \bar, docs, {dep-path: \deps}
        .to-equal do
            nice: 'day'
            deps:
                my:
                    prop: \foo
                    deps:
                        tmp:
                            x: \y
                            z: \t
                            deps: {}
                your:
                    hello: \there
            changes: clone docs.bar.changes


    'deleted a subcomponent': ->
        docs =
            bar:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
                changes:
                    deps:
                        my:
                            deps:
                                a:
                                    key: \qux
                                    deps:
                                        me: {+deleted}
            foo:
                _id: 'foo'
                hello: 'there'

            qux:
                hi: \qux
                deps:
                    me:
                        key: \john
                        value: \doe
            john:
                number: 123


        expect merge-deps \bar, docs, {dep-path: \deps}
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    _id: 'foo'
                    hello: 'there'
                    key: \foo
                    deps:
                        a:
                            key: \qux
                            hi: \qux
                            deps: {}
            changes: clone docs.bar.changes



    'add extra components': ->
        docs =
            bar:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
                changes:
                    deps:
                        my:
                            deps:
                                a:
                                    key: \qux
            foo:
                _id: 'foo'
                hello: 'there'

            qux:
                hi: \qux
                deps:
                    me:
                        key: \john
                        value: \doe
            john:
                number: 123


        expect merge-deps \bar, docs, {dep-path: \deps}
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    _id: 'foo'
                    hello: 'there'
                    key: \foo
                    deps:
                        a:
                            key: \qux
                            hi: \qux
                            deps:
                                me:
                                    key: \john
                                    value: \doe
                                    number: 123
            changes: clone docs.bar.changes


    'one dependency used in multiple locations plus empty changes': ->
        docs =
            bar:
                _id: 'bar'
                nice: 'day'
                deps:
                    my123:
                        key: 'foo'
                changes:
                    deps:
                        my123: {}
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

        expect merge-deps \bar , docs, {dep-path: \deps}
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
            changes: clone docs.bar.changes



    'circular dependency 2': ->
        docs =
            bar:
                deps:
                    your:
                        key: \foo
                    my:
                        key: 'bar'

            foo:
                deps:
                    my:
                        val: \hi

        expect (-> merge-deps \bar, docs, {dep-path: \deps})
        .to-throw "merge-deps: Circular dependency is not allowed"

    'simple': ->
        docs =
            bar:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
            foo:
                _id: 'foo'
                hello: 'there'

        orig-docs = clone docs

        expect merge-deps \bar, docs, {dep-path: \deps}
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    _id: 'foo'
                    hello: 'there'
                    key: \foo

        expect docs.bar .to-equal orig-docs.bar


    'simple with modified deep change': ->
        docs =
            doc:
                nice: 'day'
                deps:
                    my:
                        key: \bar
                changes:
                    deps:
                        my:
                            key: \foo
            foo:
                hello: 'there'
                deps:
                    x:
                        key: \how
                        xamount: 4
                    y:
                        key: \how
                        xamount: 7
                changes:
                    deps:
                        x:
                            key: \hey
                            amount: 5
            hey:
                thisis: \hey
            how:
                amount: 5
                size: \grande


        expect merge-deps \doc, docs, {dep-path: \deps}
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
                        y:
                            key: \how
                            xamount: 7
                            amount: 5
                            size: \grande
                    changes: clone docs.foo.changes
            changes: clone docs.doc.changes

        # make a change
        docs.doc.changes.deps.my.deps = y: key: \well
        docs.well = seems: \great
        expect merge-deps \doc, docs, {dep-path: \deps}
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
                        y:
                            key: \well
                            seems: \great
                    changes: clone docs.foo.changes
            changes: clone docs.doc.changes

    'deleted master change': ->
        return false
        docs:
            doc:
                nice: 'day'
                deps:
                    my:
                        key: \bar
                changes:
                    deps:
                        my:
                            key: \foo
                            deps: {+deleted}
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

        expect merge-deps \doc, docs, {dep-path: \deps}
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

            changes: clone docs.doc.changes


    'simple with modified deeper remote change': ->
        docs =
            doc:
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
            foo:
                hello: 'there'
                deps:
                    x:
                        key: \how
                        some: \thing
                changes:
                    deps:
                        x:
                            key: \hey
                            amount: 5
            hey:
                thisis: \hey

            nice:
                very: \well

        expect merge-deps \doc, docs, {dep-path: \deps}
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
                    changes: clone docs.foo.changes
            changes: clone docs.doc.changes


    'simple with extra changes': ->
        docs =
            doc:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
                changes:
                    deps:
                        hey:
                            there: \hello
            foo:
                _id: 'foo'
                hello: 'there'

        expect merge-deps \doc, docs, {dep-path: \deps}
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

            changes: clone docs.doc.changes



    'circular dependency': ->
        docs =
            bar:
                deps:
                    my:
                        key: 'foo'
            foo:
                deps:
                    hey:
                        key: \foo

        expect (-> merge-deps \bar, docs, {dep-path: \deps})
        .to-throw "merge-deps: Circular dependency is not allowed"


    'non circular dependency': ->
        docs =
            a:
                components:
                    x:
                        key: \x
                    k:
                        key: \x
                    y:
                        key: \y
            x:
                components:
                    e:
                        key: \missing-dependency


        expect (-> merge-deps 'a', docs, {dep-path: \components})
        .to-throw "merge-deps: Required dependencies are not found: missing-dependency, y"


    'missing dependency': ->
        docs =
            doc:
                deps:
                    my:
                        key: \foo
            bar:
                _id: 'bar'
                hello: 'there'

        expect (-> merge-deps \doc, docs, {dep-path: \deps})
        .to-throw "merge-deps: Required dependencies are not found: foo"

    'missing dependency 2': ->
        docs = {}

        expect (-> merge-deps \doc, docs, {dep-path: \deps})
        .to-throw "merge-deps: Required dependencies are not found: doc"



    'changed remote document': ->
        docs =
            doc:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        key: \foo
                changes:
                    deps:
                        my:
                            hi: \world
            foo:
                _id: 'foo'
                hello: 'there'
                deps:
                    my1:
                        key: \foo-dep
            'foo-dep':
                _id: 'foo-dep'
                eating: 'seed'

        expect merge-deps \doc, docs, {dep-path: \deps}
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
        docs.doc.changes.deps.my.key = 'roadrunner'

        # add this dependency to the dependency sources
        docs.roadrunner =
            _id: 'roadrunner'
            its: 'working'
            deps:
                my1:
                    key: 'coyote'
                    value: 3

        docs.coyote =
            _id: 'coyote'
            name: 'coyote who runs behind roadrunner'

        # just to be sure that changes are correct
        expect docs.doc.changes.deps.my
        .to-equal do
            hi: \world
            key: \roadrunner

        expect merge-deps \doc, docs, {dep-path: \deps}
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
        docs =
            doc:
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


        expect merge-deps \doc, docs, {dep-path: \components}
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
