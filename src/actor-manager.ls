require! './core': {ActorBase}
require! 'aea/debug-log': {logger, debug-levels}
require! 'aea': {clone, sleep, merge, pack, is-nodejs}
require! 'prelude-ls': {empty, unique-by, flatten, reject, max, find}
require! './topic-match': {topic-match}
require! 'colors': {green, red, yellow}
require! 'uuid4'
require! './aea-auth':{
    hash-passwd
    get-all-permissions
}

export session-cache = {}
/* session-cache is an object, cosists of:

    token:
        user: user-that-logged-in
        date: date-of-login
        permissions:
            ro: <[ list of topics that user has read permissions ]>
            rw: <[ list of topics that user has write permissions ]>
*/

can-write = (token, topic) ->
    try
        if session-cache[token].permissions.rw
            return if topic in that => yes else no
    catch
        no

can-read = (token, topic) ->
    try
        if session-cache[token].permissions.ro
            return if topic in that => yes else no
    catch
        no


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

        unless @db
            @log.err (red "ERROR"), "no database object found, can not process auth message."
            return

        if msg.auth
            if \username of msg.auth
                # login request
                err, doc <~ @db.get-user msg.auth.username
                if err
                    @log.err "user is not found: ", err
                else
                    if doc.passwd-hash is hash-passwd msg.auth.password
                        @log.log "#{msg.auth.username} logged in."
                        err, permissions-db <~ @db.get-permissions
                        return @log.log "error while getting permissions" if err
                        token = uuid4!
                        session-cache[token] =
                            user: msg.auth.username
                            date: Date.now!
                            permissions: get-all-permissions doc.roles, permissions-db


                        delay = 10ms
                        @log.log "(...sending with #{delay}ms delay)"
                        <~ sleep delay
                        sender._inbox @msg-template! <<<< do
                            sender: @actor-id
                            auth:
                                session:
                                    token: token
                                    user: msg.auth.username
                                    permissions: session-cache[token].permissions

                        # will be used for checking read permissions
                        sender.token = token
                    else
                        @log.err "wrong password", doc, msg.auth.password
                        sender._inbox @msg-template! <<<< do
                            sender: @actor-id
                            auth:
                                session: \wrong  # FIXME: wrong password may contain some other info

            else if \logout of msg.auth
                # session end request
                unless session-cache[msg.token]
                    @log.log "No user found with the following token: #{msg.token} "
                    return
                else
                    @log.log "logging out for #{session-cache[msg.token].user}"
                    delete session-cache[msg.token]
                    sender._inbox @msg-template! <<<< do
                        auth: logout: \ok

            else if \token of msg.auth
                response = @msg-template!
                if session-cache[msg.auth.token]
                    # this is a valid session token
                    response <<<< do
                        auth:
                            session:
                                token: msg.auth.token
                                user: that.user
                                permissions: that.permissions

                else
                    # means "you are not already logged in, do a logout action over there"
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

        # check if user has write permissions for the message
        if is-nodejs!
            if (msg.token `can-write` msg.topic) or (msg.topic `topic-match` 'public.**')
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

            # check if user has read permissions for the message
            if is-nodejs!
                if (actor.token `can-read` msg.topic) or (msg.topic `topic-match` 'public.**')
                    actor._inbox msg
                else
                    #@log.log "Actor has no read permissions, dropping message"
                    void
            else
                actor._inbox msg

        @log.section \dis-vv, "------------ end of forwarding message, total forward: #{i++}---------------"
