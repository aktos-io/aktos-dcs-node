require! '../lib':{is-nodejs, merge, pack}
require! 'prelude-ls': {flatten, find}
require! 'colors': {green}
require! './auth-helpers': {hash-passwd}

calc-authorized-topics = (role, permissions-db) ->
    # returns:
    topics = {rw: [/* writable topics */], ro: [/* readable topics */]}

    r = find (._id is role), permissions-db
    unless r
        console.log "role: #{role} is not found in permissions-db"
        return
    if r.inherits
        r.inherits = flatten [r.inherits]
        # inherits some roles, add them recursively
        for role in r.inherits
            topics `merge` (calc-authorized-topics role, permissions-db)

    topics `merge` do
        rw: if r.rw then flatten([r.rw]) else []
        ro: if r.ro then flatten([r.ro]) else []

    # flatten
    topics.rw = flatten topics.rw
    topics.ro = flatten topics.ro
    return topics

export get-all-permissions = (user-roles, permissions-db) ->
    permissions = {}
    for role in flatten [user-roles]
        permissions `merge` (calc-authorized-topics role, permissions-db)
    return permissions


# --------------------------------------------------------------------------
#                                 TESTS
# --------------------------------------------------------------------------

if require.main is module
    do test = ->
        online-users =
            * _id: 'user1'
              passwd-hash: hash-passwd "hello world"
              roles:
                  'test-area-reader'

            * _id: 'user2'
              passwd-hash: hash-passwd "hello world2"
              roles:
                  \test-area-writer

            * _id: 'user3'
              passwd-hash: hash-passwd "hello world3"
              roles:
                  \my-test-role2

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

        expected-permissions =
            'test-token-for-user1':
                rw: []
                ro: ['authorization.test1']

            'test-token-for-user2':
                rw: ['authorization.test1']
                ro: ['authorization.test1']

            'test-token-for-user3':
                rw:
                    'my-test-topic-rw3'
                    'authorization.test1'
                    'my-test-topicrw4'
                ro:
                    'my-test-topic1'
                    'my-test-topic2'
                    'authorization.test1'

        # create a simulated session-cache
        tmp-session-cache = {}
        for user in online-users
            tmp-session-cache["test-token-for-#{user._id}"] =
                user: user._id
                permissions: get-all-permissions user.roles, permissions-db

        #console.log "tmp-session-cache: ", JSON.stringify tmp-session-cache, null, 2


        # check if expected permissions are identical to calculated permissions
        for token, user-session of tmp-session-cache
            for token1, expected of expected-permissions when token is token1
                if pack(user-session.permissions) isnt pack(expected)
                    console.log (red \ERROR:), "unexpected result in token #{token}"
                    console.log "expecting: ", expected
                    console.log "result: ", user-session.permissions
                    process.exit!

        console.log (green "[TEST OK]"), " Permission calculation passed the tests"
