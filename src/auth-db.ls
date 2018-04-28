'''
Usage:
    auth-db = new AuthDB users, permissions

    _err, user <~ auth-db.get-user username

    user =
        _id: username
        password: sha512 of plaintext password
        ...(what user doc contains)
        permissions:
            ro: ...
            rw: ...

'''
require! '../lib':{sleep}
require! 'prelude-ls': {find}
require! './authorization': {get-all-permissions}

export class AuthDB
    (users-db, permissions-db)->
        @users-db = if typeof! users-db is \Object
            users-db |> as-docs
        else
            users-db

        @permissions-db = if typeof! permissions-db is \Object
            permissions-db |> as-docs
        else
            permissions-db


    get: (filter-name, callback) ->
        response = switch filter-name
        | \users => @users-db
        | \permissions => @permissions-db
        <~ sleep 200ms
        callback err=null, response

    get-user: (username, callback) ->
        '''
        returns:

            userdoc <<< {permissions: {ro: .., rw: ..}}

        '''
        <~ sleep 200ms
        user = find (._id is username), @users-db
        unless user
            err = {reason: 'user not found'}
        else
            err = null
            user.permissions = get-all-permissions user.roles, @permissions-db

        callback err, user

    get-permissions: (callback) ->
        <~ sleep 200ms
        callback err=null, @permissions-db

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
