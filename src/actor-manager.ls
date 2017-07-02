require! './core': {ActorBase}
require! 'aea/debug-log': {logger, debug-levels}
require! 'aea': {clone, sleep, merge, pack, is-nodejs}
require! 'prelude-ls': {empty, unique-by, flatten, reject, max, find}
require! './topic-match': {topic-match}
require! 'colors': {green, red, yellow}
require! './auth-actor':{AuthHandler}

can-write = (token, topic) ->
    try
        if AuthHandler.session-cache[token].permissions.rw
            return if topic in that => yes else no
    catch
        no

can-read = (token, topic) ->
    try
        if AuthHandler.session-cache[token].permissions.ro
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
        @auth = new AuthHandler!

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

    inbox-put: (msg, sender) ->
        if \auth of msg
            res <~ @auth.process msg
            sender res
            # processed the auth message
        else
            @distribute-msg msg


    distribute-msg: (msg) ->
        # distribute subscribe-all messages

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
        for actor in matching-actors
            # check if user has read permissions for the message
            if is-nodejs!
                if (actor.token `can-read` msg.topic) or (msg.topic `topic-match` 'public.**')
                    actor._inbox msg
                else
                    #@log.log "Actor has no read permissions, dropping message"
                    void
            else
                actor._inbox msg
