require! '../lib': {sleep, pack, EventEmitter, Logger}
require! './actor-manager': {ActorManager}
require! './signal': {Signal}
require! 'prelude-ls': {split, flatten, keys, unique}
require! uuid4
require! './topic-match': {topic-match}


export class Actor extends EventEmitter
    (name, opts={}) ->
        super!
        @mgr = new ActorManager!
        @id = uuid4!
        @name = name or @id
        @log = new Logger @name
        @debug = opts.debug

        @msg-seq = 0
        @subscriptions = [] # subscribe all topics by default.

        @request-queue = {}

        @_state =
            kill:
                started: no
                finished: no

        @mgr.register-actor this
        @action! if typeof! @action is \Function

    msg-template: (msg) ->
        msg-raw =
            sender: null
            timestamp: Date.now! / 1000
            msg_id: @msg-seq++
            token: null

        if msg
            return msg-raw <<<< msg
        else
            return msg-raw

    subscribe: (topics) ->
        for topic in unique flatten [topics]
            @subscriptions.push topic

    unsubscribe: (topic) ->
        @subscriptions.splice (@subscriptions.index-of topic), 1

    send: (topic, payload) ~>
        if typeof! topic isnt \String
            throw "Topic is not string? topic: #{topic}"

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

        @log.log "sending request: ", enveloped if @debug
        @subscribe topic
        response-signal = new Signal!
        @request-queue[enveloped.req.seq] = response-signal

        do
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
                return unless @proxy

            if \update of msg
                @trigger \update, msg
            if \payload of msg
                @trigger \data, msg
            # deliver every message to receive-handlers
            @trigger \receive, msg
        catch
            @log.err "problem in handler: ", e

    on-topic: (topic, handler) ->
        return unless topic

        @subscribe topic unless topic in @subscriptions

        @on \data, (msg) ~>
            if msg.topic `topic-match` topic
                handler msg

    once-topic: (topic, handler) ->
        @subscribe topic unless topic in @subscriptions

        @once \data, (msg) ~>
            if msg.topic `topic-match` topic
                handler msg
                @unsubscribe topic

    send-enveloped: (msg) ->
        msg.sender = @id
        if not msg.topic and not (\auth of msg)
            @log.err "send-enveloped: Message has no topic. Not sending."
            debugger
            return
        @log.log "sending message: ", msg if @debug
        @mgr.distribute msg

    kill: (...reason) ->
        unless @_state.kill.started
            @_state.kill.started = yes
            @mgr.deregister-actor this
            @trigger \kill, ...reason
            @_state.kill.finished = yes

    request-update: ->
        #@log.log "requesting update!"
        for let topic in @subscriptions
            debugger unless topic
            @send-enveloped @msg-template do
                update: yes
                topic: topic
