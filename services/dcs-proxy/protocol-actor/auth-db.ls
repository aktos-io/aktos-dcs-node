require! '../deps':{sleep}
require! 'prelude-ls': {find}

export class AuthDB
    (@users-db, @permissions-db)->

    get: (filter-name, callback) ->
        response = switch filter-name
        | \users => @users-db
        | \permissions => @permissions-db
        <~ sleep 200ms
        callback err=null, response

    get-user: (username, callback) ->
        <~ sleep 200ms
        doc = find (._id is username), @users-db
        err = unless doc
            reason: 'user not found'
        else
            null

        callback err, doc

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