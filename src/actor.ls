require! 'aea': {sleep}
require! './core': {ActorBase}
require! './actor-manager': {ActorManager}
require! 'prelude-ls': {
    split
}

context-switch = sleep 0

export class Actor extends ActorBase
    ->
        super ...
        @mgr = new ActorManager!

        @log.sections ++= [
            #\subscriptions
        ]

        @log.section \bare, "actor \"#{@name}\" created with id: #{@actor-id}"

        @msg-seq = 0
        @subscriptions = [] # subscribe all topics by default.
        # if you want to unsubscribe from all topics, do teh following:
        # @subscriptions = void

        @_state =
            kill:
                started: no
                finished: no

        # registering to ActorManager requires completion of this
        # constructor, so manually switch the context
        <~ context-switch
        @mgr.register this
        <~ context-switch
        @action! if typeof! @action is \Function

    subscribe: (topic) ->
        # log section prefix: s1
        topics = [topic] if typeof! topic is \String
        for topic in topics when topic not in @subscriptions
            @subscriptions.push topic
        @log.section \subscriptions, "subscribing to ", topic, "subscriptions: ", @subscriptions
        @mgr.subscribe-actor this

    list-handle-funcs: ->
        methods = [key for key of Object.getPrototypeOf this when typeof! this[key] is \Function ]
        subj = [s.split \handle_ .1 for s in methods when s.match /^handle_.+/]
        @log.log "this actor has the following subjects: ", subj, name

    send: (msg-payload, topic='') ~>
        try
            @send-enveloped @msg-template do
                topic: topic
                payload: msg-payload
        catch
            @log.err "sending message failed. msg: ", msg-payload, "enveloped: ", msg-env, e

    send-enveloped: (msg) ->
        msg.sender = @actor-id
        if not msg.topic and not (\auth of msg)
            @log.err "send-enveloped: Message has no topic. Not sending."
            return
        @mgr.inbox-put msg

    on-kill: (handler) ->
        @log.warn "remove deprecated on-kill registrar, use @on 'kill' instead"
        @on \kill, handler

    kill: (...reason) ->
        unless @_state.kill.started
            @_state.kill.started = yes
            @log.section \debug-kill, "deregistering from manager"
            @mgr.deregister this
            @log.section \debug-kill, "deregistered from manager"
            @trigger.apply this, ([\kill] ++ reason)
            @_state.kill.finished = yes
