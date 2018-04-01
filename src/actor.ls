require! '../lib': {sleep, pack, EventEmitter, Logger}
require! './actor-manager': {ActorManager}
require! './signal': {Signal}
require! 'prelude-ls': {split, flatten, keys, unique}
require! uuid4
require! './topic-match': {topic-match}

export class TopicTypeError extends Error
    (@message, @topic) ->
        super ...
        Error.captureStackTrace(this, TopicTypeError)
        @type = \DiffError



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
        @this-actor-is-a-proxy = no

        @trigger-topic = {}

        @_state =
            kill:
                started: no
                finished: no

        @mgr.register-actor this

        # this context switch is important. if it is omitted, "action" method
        # will NOT be overwritten within the parent class
        # < ~ sleep 0 <= really no need for this?
        @action! if typeof! @action is \Function

    set-name: (name) ->
        @name = name
        @log.name = name

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
            throw new TopicTypeError "Topic is not a string?", topic

        if @debug => debugger
        enveloped = @msg-template! <<< do
            topic: topic
            payload: payload
        try
            @send-enveloped enveloped
            if @debug => @log.log "sending #{pack enveloped}"
        catch
            @log.err "sending message failed. msg: ", payload, e
            throw e

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

        if @debug => @log.log "sending request: ", enveloped
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
        #@log.log "Got message to inbox:", msg.payload
        <~ sleep 0  # IMPORTANT: this fixes message sequences
        if \res of msg
            if msg.res.id is @id
                if msg.res.seq of @request-queue
                    #@log.log "...and triggered request queue:", msg.payload
                    @request-queue[msg.res.seq].go msg
                    delete @request-queue[msg.res.seq]
                    return
            unless @this-actor-is-a-proxy
                #@log.warn "Not my response, simply dropping the msg: ", msg.payload
                return

        if \payload of msg
            @trigger \data, msg

        if \request-update of msg
            /* usage:

            ..on 'request-update', (msg, respond) ->
                # use msg (msg.payload/msg.topic) if necessary
                respond {my: 'response'}

            */
            # TODO: filter requests with an acceptable FPS
            @trigger \request-update, msg, (response) ~>
                @log.log "Responding to update request for topic: ", msg.topic
                @send msg.topic, response

        # also deliver messages to 'receive' handlers
        @trigger \receive, msg

    on-topic: (topic, handler) ->
        return unless topic
        # subscribe this topic
        @subscribe topic unless topic in @subscriptions

        @trigger-topic[topic] = handler
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
        <~ sleep 0
        if @debug => @log.log "sending message: ", msg
        @mgr.distribute msg

    kill: (...reason) ->
        unless @_state.kill.started
            @_state.kill.started = yes
            @mgr.deregister-actor this
            @trigger \kill, ...reason
            @_state.kill.finished = yes

    request-update: (payload) ->
        for let topic in unique @subscriptions
            unless topic `topic-match` "app.**"
                #@log.log "requesting update for ", topic
                @send-enveloped @msg-template do
                    'request-update': yes
                    topic: topic
                    payload: payload
