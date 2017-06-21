require! './core': {ActorBase}
require! 'aea/debug-log': {logger, debug-levels}
require! 'aea': {pack, unpack}
require! 'prelude-ls': {empty, unique-by, flatten, reject, max}
require! './topic-match': {topic-match}

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
        @subscription-list = unpack pack {'**': []}

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

    inbox-put: (msg) ->
        @distribute-msg msg

    distribute-msg: (msg) ->
        # distribute subscribe-all messages
        # log.section prefix: "dis"

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

            actor._inbox msg
            i++

        @log.section \dis-vv, "------------ end of forwarding message, total forward: #{i}---------------"
