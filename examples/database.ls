require! 'dcs/src/auth-helpers': {hash-passwd}
require! 'aea':{sleep}
require! 'prelude-ls': {find}

users-db =
    * _id: 'user1'
      passwd-hash: hash-passwd "hello world"
      roles:
          'test-area-reader'

    * _id: 'user2'
      passwd-hash: hash-passwd "hello world2"
      roles:
          \test-area-writer


permissions-db =
    * _id: \test-area-reader
      ro: \authorization.test1

    * _id: \test-area-writer
      inherits:
          \test-area-reader
      rw:
          \authorization.test1

    * _id: \my-test-role
      ro:
          'my-test-topic1'
          'my-test-topic2'
      rw:
          'my-test-topic-rw3'

    * _id: \my-test-role2
      inherits:
          \my-test-role
          \test-area-writer
      rw:
          'my-test-topicrw4'



class Database
    ->

    get: (filter-name, callback) ->
        response = switch filter-name
        | \users => users-db
        | \permissions => permissions-db
        <~ sleep 200ms
        callback err=null, response

    get-user: (username, callback) ->
        <~ sleep 200ms
        doc = find (._id is username), users-db
        err = unless doc
            reason: 'user not found'
        else
            null

        callback err, doc

    get-permissions: (callback) ->
        <~ sleep 200ms
        callback err=null, permissions-db



export test-db = new Database!
