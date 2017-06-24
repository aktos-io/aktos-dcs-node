require! './core': {ActorBase}
require! 'aea/debug-log': {logger, debug-levels}
require! 'aea': {clone, sleep, merge, pack}
require! 'prelude-ls': {empty, unique-by, flatten, reject, max, find}
require! './topic-match': {topic-match}

require! 'colors': {green, red, yellow}
# ---------------------------------------------------------------

is-nodejs = ->
    if typeof! process is \process
        if typeof! process.versions is \Object
            if typeof! process.versions.node isnt \Undefined
                return yes
    return no

create-hash = require 'sha.js'
require! uuid4

hash-passwd = (passwd) ->
    sha512 = create-hash \sha512
    sha512.update passwd, 'utf-8' .digest \hex

user-db =
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

permission-db =
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

session-cache = {}      # key: token, value: {user: user-that-logged-in, date: date-of-login}
permission-cache = {}   # key: token, value: {rw: [...topics], ro: [...topics]}

update-permission-cache = ->
    calc-topics = (role) ->
        # returns:
        # {rw: [...topics], ro: [...topics]}
        topics =
            rw: []
            ro: []
        r = find (._id is role), permission-db
        unless r
            console.log "role: #{role} is not found in permission-db"
            return
        if r.inherits
            r.inherits = flatten [r.inherits]
            # inherits some roles, add them recursively
            for role in r.inherits
                topics `merge` calc-topics role

        topics `merge` do
            rw: if r.rw then flatten([r.rw]) else []
            ro: if r.ro then flatten([r.ro]) else []

        # flatten
        topics.rw = flatten topics.rw
        topics.ro = flatten topics.ro
        topics

    token-topics = {}
    for token, t of session-cache
        for u in user-db when t.user is u._id
            token-topics[token] = {}
            for role in flatten [u.roles]
                token-topics[token] `merge` calc-topics role
    permission-cache := token-topics

if is-nodejs!
    do test = ->
        # treat all users logged in
        for user in user-db
            session-cache["test-token-for-#{user._id}"] =
                user: user._id

        update-permission-cache!

        expected =
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

        for token, topics of permission-cache
            for token1, expected-topics of expected when token is token1
                if pack(topics) isnt pack(expected-topics)
                    console.log "unexpected result in token #{token}"
                    console.log "expecting: ", expected-topics
                    console.log "result: ", topics
                    throw

        console.log (green "[TEST OK]"), " Permission calculation passed the tests"
        # cleanup
        permission-cache := {}
        session-cache := {}

has-write-permission-for = (token, topic) ->
    try
        permission-cache[token].rw and topic in permission-cache[token].rw
    catch
        no

has-read-permission-for = (token, topic) ->
    try
        permission-cache[token].ro and topic in permission-cache[token].ro
    catch
        no

# ---------------------------------------------------------------

export class ActorManager extends ActorBase
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this

        super \ActorManager
        @actor-list = [] # actor-object
        @subs-min-list = {}    # 'topic': [list of actors subscribed this topic]
        #@log.level = debug-levels.silent
        @update-subscriptions!

        @log.sections ++= [
            #\v
            #\vv
            #\vvv
            #\v3
            #\v4
            #\dis-4
            #\dis-v
            #\dis-vv
            #\dis-5
            #\dis-vv7
            #\deregister
        ]

    register: (actor) ~>
        if actor.actor-id not in [..actor-id for @actor-list]
            @actor-list.push actor
            @log.section \v, """\"#{actor.actor-id}\" #{"(#{actor.name})" if actor.name}has been registered. total: #{@actor-list.length}"""
        else
            @log.err "This actor has been registered before!", actor

        @update-subscriptions!

    deregister: (actor) ~>
        @log.section \deregister, "deregistering actor: #{actor.actor-id}"
        @log.section \deregister, "actor count before: ", @actor-list.length
        @actor-list = reject (.actor-id is actor.actor-id), @actor-list
        @log.section \deregister, "actor count after: ", @actor-list.length
        @update-subscriptions!

    update-subscriptions: ->
        # log section prefix: v3
        # update subscriptions
        @subscription-list = clone {'**': []}

        for actor in @actor-list
            continue if actor.subscriptions is void
            if '**' in actor.subscriptions
                s = @subscription-list['**']
                if actor.actor-id not in [..actor-id for s]
                    s.push actor
                continue
            else
                for topic in actor.subscriptions
                    unless @subscription-list[topic]
                        @subscription-list[topic] = []
                    s = @subscription-list[topic]
                    if actor.actor-id not in [..actor-id for s]
                        s.push actor

        @log.section \v3, "Subscriptions: ", @subscription-list

    subscribe-actor: (actor) ->
        # log section prefix: v4
        entry = [.. for @actor-list when ..actor-id is actor.actor-id]
        entry.subscriptions = actor.subscriptions
        @update-subscriptions!

    process-auth-msg: (msg) ->
        unless is-nodejs!
            # this is browser, just drop the message right away
            @log.log "dropping auth message as this is browser."
            return

        # FIXME: rather than searching whole actor-list, actors should pass
        # their own object reference by the message for two way communication
        sender = find (.actor-id is msg.sender), @actor-list
        # /FIXME

        @log.log "this is an authentication message"

        if msg.auth
            if \username of msg.auth
                # login request
                doc = find (._id is msg.auth.username), user-db

                if not doc
                    @log.err "user is not found"
                else
                    if doc.passwd-hash is hash-passwd msg.auth.password
                        token = uuid4!
                        session-cache[token] =
                            user: msg.auth.username
                            date: Date.now!
                        @log.log "user logged in. hash: #{token}"

                        update-permission-cache!
                        delay = 500ms
                        @log.log "(...sending with #{delay}ms delay)"
                        <~ sleep delay
                        sender._inbox @msg-template! <<<< do
                            sender: @actor-id
                            auth:
                                session:
                                    token: token
                                    user: msg.auth.username

                        # will be used for checking read permissions
                        sender.token = token
                    else
                        @log.err "wrong password", doc, msg.auth.password
            else if \logout of msg.auth
                # session end request
                unless session-cache[msg.token]
                    @log.log "No user found with the following token: #{msg.token} "
                    return
                else
                    @log.log "logging out for #{session-cache[msg.token].user}"
                    delete session-cache[msg.token]
                    update-permission-cache!
                    sender._inbox @msg-template! <<<< do
                        auth: logout: \ok

            else if \token of msg.auth
                response = @msg-template!
                if curr = session-cache[msg.auth.token]
                    # this is a valid session token
                    response <<<< do
                        auth:
                            session:
                                token: msg.auth.token
                                user: curr.user
                else
                    response <<<< auth: logout: 'yes'

                @log.log "tried to login with token: ", pack response
                sender._inbox response

            else
                @log.err yellow "Can not determine which auth request this was: ", msg

    inbox-put: (msg) ->
        if is-nodejs!
            if \auth of msg
                @process-auth-msg msg
                return
        @distribute-msg msg


    distribute-msg: (msg) ->
        # distribute subscribe-all messages
        # log.section prefix: "dis"

        if is-nodejs!
            if (msg.token `has-write-permission-for` msg.topic) or
                (msg.topic `topic-match` 'public.**')
                #@log.log green "distributing message", msg.topic, msg.payload
                void
            else
                #@log.log red "dropping unauthorized write message (#{msg.topic})"
                return


        matching-subscriptions = [actors for topic, actors of @subscription-list
            when topic `topic-match` msg.topic]

        matching-actors = unique-by (.actor-id), flatten matching-subscriptions
        matching-actors = reject (.actor-id is msg.sender), matching-actors

        i = 0
        @log.section \dis-4, "Topic: #{msg.topic}, Matching actors: ", matching-actors.length
        @log.section \dis-5, "Subscriptions: ", @subscription-list
        @log.section \dis-vv, "------------ forwarding message ---------------"

        @log.section \dis-v, "Distributing topic: #{msg.topic}"
        for actor in matching-actors
            @log.section \dis-vv7, "------------ forwarding #{msg.topic} message to actor #{actor.actor-id} ---------------"
            @log.section \dis-v, "forwarding msg: #{msg.msg_id} to #{actor.name}"
            @log.section \dis-vv, "actor: ", actor
            @log.section \dis-vv, "message: ", msg
            @log.section \dis-vv, "------------- end of forwarding to actor ---------------"

            if is-nodejs!
                if (actor.token `has-read-permission-for` msg.topic) or
                    (msg.topic `topic-match` 'public.**')
                    actor._inbox msg
                else
                    #@log.log "Actor has no read permissions, dropping message"
                    void
            else
                actor._inbox msg

        @log.section \dis-vv, "------------ end of forwarding message, total forward: #{i++}---------------"
