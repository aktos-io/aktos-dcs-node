'''
Users are also roles (groups). Fields are:

'my-user':
    password-hash: sha512 of password (optional, can not login if this field is
        omitted, thus it is a role/group name only)

    roles: Array of role names to inherit

        'some-role'
        'some-other-role' # or user
        '!some-restricted-role'

    routes: Array of routes that the user can communicate with

        'some-topic.some-child.*'   # => send/receive to/from that topic along with other subscribers
        '@some-user.**'             # => communicate only with @some-user
                                         login username should match in order to
                                         receive this messages.
        '! some-other-topic.**'     # => disable for that route

    permissions: Array of domain specific permissions/filter names.
        In order to negate the filter, prepend "!" to the beginning.

        'db.own-clients'
        'db.production-job'
        '!db.get.design-docs'
        '!db.put.design-docs'

        > Applications are responsible for filtering their output by taking these
        > filters into account.


Usage: (see tests below)
'''
require! '../lib':{sleep, merge, clone}
require! 'prelude-ls': {find, partition, flatten}
require! './topic-match': {topic-match}

export class AuthDB
    @@instance = null
    (users) ->
        return @@instance if @@instance
        @@instance = this
        @update users

    update: (users) ->
        @users-db = if typeof! users is \Object
            users |> as-docs
        else
            users

    get: (username) ->
        user = merge-user-doc username, @users-db

export as-docs = (obj) ->
    # convert object to couchdb like documents
    """
        foo:
            bar: 'baz'
        foo2:
            fizz: 'buzz'

    as-docs:

        [
            {_id: 'foo', bar: 'baz'},
            {_id: 'foo2', fizz: 'buzz'}
        ]

    """
    docs = []
    for id, doc of obj
        doc._id = id
        docs.push doc
    return docs

calc-negation = (arr) ->
    if arr
        [negs, normals] = partition (.match /^!.+/), that
        negs = negs.map (.replace /^!/, '')
        return for normals
            unless .. `topic-match` negs
                ..
    else
        return undefined

export merge-user-doc = (username, user-docs) ->
    unless user-docs => throw "Empty user docs."
    user = find (._id is username), user-docs
    unless user => throw "No such user found: #{username}"
    user = clone user

    # let routes and permissions be array or string
    if user.routes => user.routes = flatten [user.routes]
    if user.permissions => user.permissions = flatten [user.permissions]

    _user = {}
    if user.roles
        for flatten [that]
            _role = clone (merge-user-doc .., user-docs)
            try delete _role._id
            try delete _role._rev
            try delete _role.passwd-hash
            #console.log "role is: ", _role
            _user `merge` _role

    result = _user `merge` user
    result.routes = calc-negation result.routes
    result.permissions = calc-negation result.permissions
    return result

if require.main is module
    require! '../lib/test-utils': {make-tests}

    users =
        'cca':
            passwd-hash: 123
            roles: <[ me him ]>
            opening-scene: \orders
            hello: \baby

        'me':
            hey: \first

        'him':
            hey: \second

        'foo':
            hey: 'me'
            roles: <[ me him foo-like ]>
            routes:
                \@hello.there


        'foo-like':
            routes:
                \world.is.great
                ...

        'bar':
            roles: <[ foo ]>
            routes:
                \!world.is.great
                ...

        'baz':
            roles: <[ foo ]>
            routes:
                \!world.is.great
                ...
            permissions:
                \db.own-clients
                \plc.input

        'qux':
            roles: <[ baz ]>
            permissions:
                \!db.*
                ...


    auth = new AuthDB users

    make-tests 'AuthDB Tests', do
        'simple': ->
            expect auth.get \cca
            .to-equal do
                _id: \cca
                passwd-hash: 123
                roles: <[ me him ]>
                opening-scene: \orders
                hey: \second
                hello: \baby

        'simple2': ->
            expect auth.get \foo
            .to-equal do
                _id: \foo
                roles: <[ me him foo-like ]>
                hey: \me
                routes:
                    \world.is.great
                    \@hello.there

        'route-exclusion': ->
            expect auth.get \bar
            .to-equal do
                _id: \bar
                roles: <[ me him foo-like foo ]>
                hey: \me
                routes:
                    \@hello.there
                    ...

        'permissions': ->
            expect auth.get \baz
            .to-equal do
                _id: \baz
                roles: <[ me him foo-like foo ]>
                hey: \me
                routes:
                    \@hello.there
                    ...
                permissions:
                    \db.own-clients
                    \plc.input

        'wildcard exclusion': ->
            expect auth.get \qux
            .to-equal do
                _id: \qux
                roles: <[ me him foo-like foo baz ]>
                hey: \me
                routes:
                    \@hello.there
                    ...
                permissions:
                    \plc.input
                    ...
