require! '../lib': {sleep, pack, EventEmitter, Logger}
require! './actor-manager': {ActorManager}
require! './signal': {Signal}
require! 'prelude-ls': {split, flatten, keys, unique}
require! uuid4
require! './topic-match': {topic-match: route-match}

/*
message =
    from: ID of sender actor's ID
    to: String or Array of routes that the message will be delivered to
    seq: sequence number of message (integer, autoincremental)
    part: part number of this specific message, integer ("undefined" for single messages)
        multi part messages include "part" attribute, `-1` for end of chunks
        streams will just increment this attribute for every frame
    data: data of message

    # control attributes
    #--------------------
    re: "#{from}.#{seq}" # optional, if this is a response for a request
    nack: true (we don't need acknowledgement message, just like UDP)
    req: true (this is a request, I'm waiting for the response)
    ack: true (acknowledgement messages)
    heartbeat: integer (wait at least for this amount of time for next part)


ack message fields:
    from, to, seq, part?, re, +ack

Request message:
    Unicast:

        from, to: "@some-user.some-route", seq, part?, data?, +req

    Multicast:

        Not defined yet.

Response:
    Unicast response    : from, to, seq, re: "...",
    Multicast response  : from, to, seq, re: "...", +all,

        Response (0) -> part: 0, +ack

        Response (1..x) -> part: ++, data: ...

        Control messages:
            part: ++, heartbeat: 200..99999ms

        Response (end) -> part: -1, data: ...


Broadcast message:
    from, to: "**", seq, part?, data, +nack

    ("**": means "to all _available_ routes")


Multicast message:

    from, to: ["@some-user.some-route", ..], seq, part?, data?, +no_ack
*/

export class TopicTypeError extends Error
    (@message, @route) ->
        super ...
        Error.captureStackTrace(this, TopicTypeError)
        @type = \TopicTypeError



export class Actor extends EventEmitter
    (name, opts={}) ->
        super!
        @mgr = new ActorManager!
        @id = uuid4!
        @name = name or @id
        @log = new Logger @name
        @msg-seq = 0
        @subscriptions = [] # subscribe all routes by default.
        @request-queue = {}
        @this-actor-is-a-proxy = no
        @_route_handlers = {}
        @_state = {}
        @mgr.register-actor this
        # this context switch is important. if it is omitted, "action" method
        # will NOT be overwritten within the parent class
        # < ~ sleep 0 <= really no need for this?
        @action! if typeof! @action is \Function

    set-name: (name) ->
        @name = name
        @log.name = name

    msg-template: (msg={}) ->
        msg-raw =
            from: @id
            to: null
            timestamp: Date.now! / 1000
            seq: @msg-seq++
            token: null
        return msg-raw <<< msg

    subscribe: (routes) ->
        for route in unique flatten [routes]
            @subscriptions.push route

    unsubscribe: (route) ->
        @subscriptions.splice (@subscriptions.index-of route), 1

    send: (route, data) ~>
        if typeof! route isnt \String
            throw new TopicTypeError "Topic is not a string?", route
        enveloped = @msg-template {to: route, data}
        @send-enveloped enveloped

    send-request: (_route, data, callback) ->
        /*
        opts:
            timeout: milliseconds
        */
        # normalize parameters
        switch typeof! _route
            when \String => [route, timeout] = [_route, 0]
            when \Object => [route, timeout] = [_route.route, _route.timeout]

        if typeof! data is \Function
            # data might be null
            callback = data
            data = null

        enveloped = @msg-template {to: route, data}

        enveloped <<< do
            req:
                id: @id
                seq: enveloped.seq

        if @debug => @log.debug "sending request: ", enveloped
        @subscribe route
        response-signal = new Signal!
        @request-queue[enveloped.req.seq] = response-signal

        do
            timeout = timeout or 1000ms
            err, msg <~ response-signal.wait timeout
            @unsubscribe route
            callback err, msg

        @send-enveloped enveloped

    send-response: (req, data) ->
        enveloped = @msg-template  do
            to: req.to
            data: data
            res:
                id: req.req?.id
                seq: req.req?.seq

        #console.log "response sending: ", pack enveloped.res
        @send-enveloped enveloped

    _inbox: (msg) ->
        # process one message at a time
        #@log.log "Got message to inbox:", msg.data
        <~ sleep 0  # IMPORTANT: this fixes message sequences
        if \res of msg
            if msg.res.id is @id
                if msg.res.seq of @request-queue
                    #@log.log "...and triggered request queue:", msg.data
                    @request-queue[msg.res.seq].go msg
                    delete @request-queue[msg.res.seq]
                    return
            unless @this-actor-is-a-proxy
                #@log.warn "Not my response, simply dropping the msg: ", msg.data
                return

        if \data of msg
            @trigger \data, msg

        # also deliver messages to 'receive' handlers
        @trigger \receive, msg

    on-topic: (route, handler) ->
        unless route => throw "Need a route."

        # subscribe this route
        @subscribe route unless route in @subscriptions

        @_route_handlers[][route].push handler
        @on \data, (msg) ~>
            if msg.to `route-match` route
                handler msg


    trigger-topic: (route, ...args) ->
        for handler in @_route_handlers[route]
            handler ...args

    once-route: (route, handler) ->
        @subscribe route unless route in @subscriptions

        @once \data, (msg) ~>
            if msg.to `route-match` route
                handler msg
                @unsubscribe route

    send-enveloped: (msg) ->
        if not msg.to and not (\auth of msg)
            return @log.err "send-enveloped: Message has no route. Not sending.", msg
        <~ sleep 0
        if @debug => @log.debug "sending message: ", msg
        @mgr.distribute msg, @id

    kill: (...reason) ->
        unless @_state.kill-started
            @_state.kill-started = yes
            @mgr.deregister-actor this
            @trigger \kill, ...reason
            @_state.kill-finished = yes

    on-every-login: (callback) ->
        @on-topic 'app.dcs.connect', (msg) ~>
            callback msg

        # request dcs login state on init
        @send-request 'app.dcs.update', (err, msg) ~>
            #@log.info "requesting app.dcs.connect state:"
            if not err and msg?data
                callback msg
            else
                @log.warn "invalid response: ", msg

if require.main is module
    console.log "initializing actor test"
    new class A1 extends Actor
        action: ->
            @on-topic "hello", (msg) ~>
                @log.log "received hello message", msg

    new class A2 extends Actor
        action: ->
            @on-topic "hello", (msg) ~>
                @log.err "received hello message", msg

            @send "hello", {hello: \there}
