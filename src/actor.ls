require! 'aea': {sleep}
require! './core': {ActorBase}
require! './actor-manager': {ActorManager}
require! 'prelude-ls': {
    split, flatten
}

context-switch = sleep 0

export class Actor extends ActorBase
    (name, opts={})->
        super name
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
        unless opts.register-manually
            <~ context-switch
            @mgr.register this
            <~ context-switch
            @action! if typeof! @action is \Function

    subscribe: (topics) ->
        # log section prefix: s1
        topics = flatten [topics]
        for topic in topics when topic not in @subscriptions
            @subscriptions.push topic
        #@log.log "subscribing to ", topic, "subscriptions: ", @subscriptions
        @mgr.subscribe-actor this

    send: (payload, topic='') ~>
        enveloped = @msg-template! <<< do
            topic: topic
            payload: payload
        try
            @send-enveloped enveloped
        catch
            @log.err "sending message failed. msg: ", payload, e

    send-enveloped: (msg) ->
        msg.sender = @id
        if not msg.topic and not (\auth of msg)
            @log.err "send-enveloped: Message has no topic. Not sending."
            return
        @mgr.inbox-put msg, (@_inbox.bind this)

    request-update: (topic) ->
        @log.log "requesting update for topic: #{topic}"
        @send-enveloped @msg-template do
            update: yes
            topic: topic

    kill: (...reason) ->
        unless @_state.kill.started
            @_state.kill.started = yes
            @log.section \debug-kill, "deregistering from manager"
            @mgr.deregister this
            @log.section \debug-kill, "deregistered from manager"
            @trigger.apply this, ([\kill] ++ reason)
            @_state.kill.finished = yes
