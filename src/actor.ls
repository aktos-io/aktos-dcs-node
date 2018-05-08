require! '../lib': {sleep, pack, EventEmitter, Logger, merge}
require! './actor-manager': {ActorManager}
require! './signal': {Signal}
require! 'prelude-ls': {split, flatten, keys, unique, is-it-NaN}
require! uuid4
require! './topic-match': {topic-match: route-match}

/*
message =
    from: ID of sender actor's ID
    to: String or Array of routes that the message will be delivered to
    seq: sequence number of message (integer, autoincremental)
    data: data of message

    # control attributes (used for routing)
    #------------------------------------------
    re: "#{from}.#{seq}" # optional, if this is a response for a request
    part: part number of this specific message, integer ("undefined" for single messages)
        Partial messages should include "part" attribute (0 based, autoincremented),
        `-1` for end of chunks.
        Streams should use `-2` as `part` attribute for every frame.
    req: true (this is a request, I'm waiting for the response)
    timeout: integer (wait at least for this amount of time for next part)

    # extra attributes
    #--------------------
    method: Method to use concatenating partial transfers. Default is `merge`
        function. If present, application will handle the concatenation.
    permissions: Array of calculated user permissions.

    # optional attributes
    #----------------------
    nack: true (we don't need acknowledgement message, just like UDP)
    ack: true (acknowledgement messages)


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


LAST_PART = -1

export class Actor extends EventEmitter
    (name, opts={}) ->
        super!
        @mgr = new ActorManager!
        @id = @mgr.next-actor-id!
        @name = name or @id
        @log = new Logger @name
        @msg-seq = 0
        @subscriptions = [] # subscribe all routes by default.
        @request-queue = {}
        @_route_handlers = {}
        @_state = {}
        @_requests = {}
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
            when \String =>
                route = _route
                timeout = null
            when \Object =>
                route = if _route.topic?
                    _route.topic
                else if _route.route
                    _route.route
                timeout = _route.timeout

        if typeof! data is \Function
            # data might be null
            callback = data
            data = null

        enveloped = @msg-template {to: route, data, +req}

        # make preperation for the response
        @subscribe route
        timeout = timeout or 1000ms

        part-handler = ->
        complete-handler = ->
        reg-part-handlers =
            on-part: (func) ~>
                part-handler := func
            on-complete: (func) ~>
                complete-handler := func
            send-part: (msg, last-part=no) ~>
                @log.todo "Sending next part"
        do
            response-signal = new Signal!
            @request-queue[enveloped.seq] = response-signal
            error = null
            prev-pieces = {}
            message = {}
            merge-method-manual = no
            <~ :lo(op) ~>
                err, msg <~ response-signal.wait timeout
                if err
                    #@log.err "We have timed out"
                    error := err
                    return op!
                else
                    #@log.success "GOT RESPONSE SIGNAL"
                    part-handler msg
                    if msg.timeout => timeout := that
                    if msg.method?
                        merge-method-manual := yes
                    unless merge-method-manual
                        message `merge` msg
                    if not msg.part? or msg.part < 0
                        /*
                        if not msg.part?
                            @log.debug "this was a single part response."
                        else
                            @log.debug "this was the last part of the message chain."
                        */
                        return op!
                lo(op)

            # Got the full messages (or error) at this point.
            @unsubscribe route
            delete @request-queue[enveloped.seq]

            if merge-method-manual
                error := "Merge method is set to manual. We can't concat the messages."
            #@log.log "Received full message: ", message
            complete-handler error, message
            if typeof! callback is \Function
                callback error, message

        @send-enveloped enveloped
        return reg-part-handlers

    send-response: (req, meta, data) ->
        unless req.req
            return @log.debug "No request is required, doing nothing."

        # normalize parameters
        if typeof! data is \Undefined
            data = meta
            meta = {}

        resp-id = "#{req.from}.#{req.seq}"
        if meta.part
            unless @_requests[resp-id]?
                @_requests[resp-id] = 0
            meta.part = @_requests[resp-id]++
        else
            if @_requests[resp-id]?
                # this is the last part of a parted message
                delete @_requests[resp-id]
                meta.part = LAST_PART
            else
                @log.warn "Dropping response part after last part."

        enveloped = @msg-template {
            to: req.from
            data
            re: req.seq
        } <<< meta
        #@log.debug "sending the response for request: ", enveloped
        @send-enveloped enveloped

    _inbox: (msg) ->
        #@log.log "Got message to inbox:", msg
        msg.{}ctx.permissions = (try msg.ctx.permissions) or []
        <~ sleep 0  # IMPORTANT: this fixes message sequences
        message-owner = msg.to.split '.' .[*-1]
        if msg.re? and message-owner is @id
            if @request-queue[msg.re]
                # this is a response
                #@log.debug "We were expecting this response: ", msg
                @request-queue[msg.re]?.go msg
            else
                @log.err "This is not a message we were expecting?", msg
            return

        if \data of msg
            @trigger \data, msg

        # also deliver messages to 'receive' handlers
        @trigger \receive, msg

    on-topic: (route, handler) ->
        unless route => throw "Need a route."

        # subscribe this route
        @subscribe route unless route in @subscriptions

        @on \data, (msg) ~>
            if msg.to `route-match` route
                handler msg

        # for "trigger-topic" method to work
        @_route_handlers[][route].push handler


    trigger-topic: (route, ...args) ->
        for handler in @_route_handlers[route]
            handler ...args

    once-topic: (route, handler) ->
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
