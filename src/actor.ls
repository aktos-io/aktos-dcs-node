require! 'aea': {sleep}
require! './core': {ActorBase, envelp}
require! './actor-manager': {ActorManager}
require! 'prelude-ls': {
    split
}

export class Actor extends ActorBase
    (name) ->
        super ...
        @mgr = new ActorManager!

        @actor-name = name
        #@log.sections.push \s1

        @log.section \bare, "actor \"#{@name}\" created with id: #{@actor-id}"

        @msg-seq = 0
        @subscriptions = [] # subscribe all topics by default.
        # if you want to unsubscribe from all topics, do teh following:
        # @subscriptions = void 

        @kill-handlers = []

        @_state =
            kill:
                started: no
                finished: no

        # registering to ActorManager requires completion of this
        # constructor, so manually switch the context
        <~ sleep 1ms
        @mgr.register this
        <~ sleep 0 # context-switch
        @action! if typeof! @action is \Function

    subscribe: (topic) ->
        # log section prefix: s1
        topics = [topic] if typeof! topic is \String
        for topic in topics when topic not in @subscriptions
            @subscriptions.push topic
        @log.section \s1, "subscribing to ", topic, "subscriptions: ", @subscriptions
        @mgr.subscribe-actor this

    list-handle-funcs: ->
        methods = [key for key of Object.getPrototypeOf this when typeof! this[key] is \Function ]
        subj = [s.split \handle_ .1 for s in methods when s.match /^handle_.+/]
        @log.log "this actor has the following subjects: ", subj, name

    send: (msg-payload, topic=null) ~>

        unless topic
            @log.err "send: SET TOPIC! (setting topic to '*')"
            topic = "*"
        try
            msg-env = envelp msg-payload, @msg-seq++
            msg-env.topic = topic
            @send_raw msg-env
        catch
            @log.err "sending message failed. msg: ", msg-payload, "enveloped: ", msg-env, e

    send_raw: (msg_raw) ->
        msg_raw.sender = @actor-id
        @mgr.inbox-put msg_raw

    on-kill: (handler) ->
        @log.section \debug1, "adding handler to run on-kill..."
        if typeof! handler isnt \Function
            @log.err "parameter passed to 'on-kill' should be a function."
            return
        @kill-handlers.push handler

    kill: (reason) ->
        @_state.kill.started = yes
        unless @_state.kill.started
            @mgr.deregister this
            try
                for handler in @kill-handlers
                    handler.call this, reason
            catch
                @log.err "problem in kill handler: ", e

            @_state.kill.finished = yes
