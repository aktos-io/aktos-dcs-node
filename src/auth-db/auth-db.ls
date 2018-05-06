# Usage: (see tests)

require! '../../lib':{sleep, merge, clone}
require! 'prelude-ls': {find, partition, flatten}
require! '../topic-match': {topic-match}

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
        for role-name in flatten [that]
            exclude = no
            if role-name.0 is "!"
                # this is an exclusion
                role-name = role-name.slice 1 .trim!
                exclude = yes
            _role = clone (merge-user-doc role-name, user-docs)
            try delete _role._id
            try delete _role._rev
            try delete _role.passwd-hash

            # remove user specific routes
            for i, route of _role.routes
                if route `topic-match` "@#{role-name}.**"
                    _role.routes.splice i, 1

            if exclude
                for <[ permissions routes ]>
                    if arr=_role[..]
                        for index, item of arr
                            unless item.match /^!.*/
                                arr[index] = "!#{item}"
                #console.log "excluded role is: ", _role
            _user `merge` _role

    result = _user `merge` user
    result.routes = calc-negation result.routes
    result.[]routes.unshift "@#{username}.**"
    result.permissions = calc-negation result.permissions
    return result

if require.main is module
    console.log "run ./tests.ls"
