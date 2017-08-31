require! 'aea': {sleep, pack}
require! './actor-base': {ActorBase}
require! './actor-manager': {ActorManager}
require! 'prelude-ls': {
    split, flatten, keys
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

        @request-queue = {}

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

    send: (topic, payload) ~>
        if (typeof! payload is \String) and (typeof! topic is \Object)
            # swap the parameters
            _tmp = payload
            payload = topic
            topic = _tmp

        debugger if @debug
        enveloped = @msg-template! <<< do
            topic: topic
            payload: payload
        try
            @send-enveloped enveloped
            @log.log "sending #{pack enveloped}" if @debug
        catch
            @log.err "sending message failed. msg: ", payload, e

    send-request: (topic, payload, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}

        /*
        opts:
            timeout: milliseconds
        */

        enveloped = @msg-template! <<< do
            topic: topic
            payload: payload

        enveloped <<< do
            req:
                id: @id
                seq: enveloped.msg_id

        @request-queue[enveloped.req.seq] = callback
        @send-enveloped enveloped

    send-response: (msg-to-response-to, payload) ->
        enveloped = @msg-template! <<< do
            topic: msg-to-response-to.topic
            payload: payload
            res:
                id: msg-to-response-to.req?.id
                seq: msg-to-response-to.req?.seq

        #console.log "response sending: ", pack enveloped.res
        @send-enveloped enveloped

    _inbox: (msg) ->
        # process one message at a time
        try
            if \res of msg
                if msg.res.id is @id
                    if msg.res.seq of @request-queue
                        @request-queue[msg.res.seq] err=null, msg
                        delete @request-queue[msg.res.seq]
                        return

            if \update of msg
                @trigger \update, msg
            if \payload of msg
                @trigger \data, msg
            # deliver every message to receive-handlers
            @trigger \receive, msg
        catch
            @log.err "problem in handler: ", e

    send-enveloped: (msg) ->
        msg.sender = @id
        if not msg.topic and not (\auth of msg)
            @log.err "send-enveloped: Message has no topic. Not sending."
            return
        @mgr.inbox-put msg, (@_inbox.bind this)

    kill: (...reason) ->
        unless @_state.kill.started
            @_state.kill.started = yes
            @log.section \debug-kill, "deregistering from manager"
            @mgr.deregister this
            @log.section \debug-kill, "deregistered from manager"
            @trigger.apply this, ([\kill] ++ reason)
            @_state.kill.finished = yes

    request-update: ->
        <~ context-switch
        #@log.log "requesting update!"
        for topic in @subscriptions
            @send-enveloped @msg-template do
                update: yes
                topic: topic
