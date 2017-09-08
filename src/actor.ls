require! 'aea': {sleep, pack}
require! './actor-base': {ActorBase}
require! './actor-manager': {ActorManager}
require! './signal': {Signal}
require! 'prelude-ls': {
    split, flatten, keys, unique
}

context-switch = sleep 0

export class Actor extends ActorBase
    (name, @opts={}) ->
        super name
        @mgr = new ActorManager!

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

        @mgr.register-actor this
        <~ context-switch # required to properly set the context
        try @action!

    subscribe: (topics) ->
        for topic in unique flatten [topics]
            @subscriptions.push topic

    unsubscribe: (topic) ->
        @subscriptions.splice (@subscriptions.index-of topic), 1

    send: (topic, payload) ~>
        if typeof! payload isnt \Object
            # swap the parameters
            [payload, topic] = [topic, payload]

        if typeof! topic isnt \String
            @log.warn "Topic is not string? topic: #{topic}"

        debugger if @debug
        enveloped = @msg-template! <<< do
            topic: topic
            payload: payload
        try
            @send-enveloped enveloped
            @log.log "sending #{pack enveloped}" if @debug
        catch
            @log.err "sending message failed. msg: ", payload, e

    send-request: (_topic, payload, callback) ->
        /*
        opts:
            timeout: milliseconds
        */
        # normalize parameters
        switch typeof! _topic
            when \String => [topic, timeout] = [_topic, 0]
            when \Object => [topic, timeout] = [_topic.topic, _topic.timeout]

        enveloped = @msg-template! <<< do
            topic: topic
            payload: payload

        enveloped <<< do
            req:
                id: @id
                seq: enveloped.msg_id

        @log.log "sending request: ", enveloped if @opts.debug
        @subscribe topic
        response-signal = new Signal!
        @request-queue[enveloped.req.seq] = response-signal

        do
            @log.log "waiting for response"
            timeout, msg <~ response-signal.wait timeout
            @unsubscribe topic
            callback timeout, msg

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
                        @request-queue[msg.res.seq].go msg
                        delete @request-queue[msg.res.seq]
                        return

            if \update of msg
                @trigger \update, msg
            if \payload of msg
                @trigger \data, msg
            # deliver every message to receive-handlers
            @trigger \receive, msg
        catch
            debugger
            @log.err "problem in handler: ", e

    send-enveloped: (msg) ->
        msg.sender = @id
        if not msg.topic and not (\auth of msg)
            @log.err "send-enveloped: Message has no topic. Not sending."
            return
        @log.log "sending message: ", msg if @opts.debug
        @mgr.distribute msg

    kill: (...reason) ->
        unless @_state.kill.started
            @_state.kill.started = yes
            @log.section \debug-kill, "deregistering from manager"
            @mgr.deregister-actor this
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
