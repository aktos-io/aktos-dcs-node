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
    seq: Sequence number of message (integer, autoincremental). Every unique message
        receives a new sequence number. Partial messages share the same sequence number,
        they are identified with their `part` attribute.
    data: data of message

    # control attributes (used for routing)
    #------------------------------------------
    re: "#{from}.#{seq}" # optional, if this is a response for a request
    cc: "Carbon Copy": If set to true, message is also delivered to this route.
    res-token: One time response token for that specific response. Responses are dropped
        without that correct token.
    part: part number of this specific message, integer ("undefined" for single messages)
        Partial messages should include "part" attribute (0 based, autoincremented),
        `-1` for end of chunks.
        Streams should use `-2` as `part` attribute for every frame.
    req: true (this is a request, I'm waiting for the response)
    timeout: integer (wait at least for this amount of time for next part)

    # extra attributes
    #--------------------
    merge: If set to false, partials are concatenated by application (outside of)
        actor. If omitted, `aea.merge` method is used.
    permissions: Array of calculated user permissions.
    debug: if set to true, message highlights the route it passes

    # optional attributes
    #----------------------
    nack: true (we don't need acknowledgement message, just like UDP)
    ack: true (acknowledgement messages)
    timestamp: Unix time in milliseconds



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
message-owner = (.to.split '.' .[*-1])  # last part of "to:" attribute

export class Actor extends EventEmitter
    (name, opts={}) ->
        super!
        @mgr = new ActorManager!
        @id = @mgr.next-actor-id!
        @me = @id
        @name = name or @id
        @log = new Logger @name
        @msg-seq = 0
        @subscriptions = [@me]
        @request-queue = {}
        @_route_handlers = {}
        @_state = {}
        @_partial_msg_states = {}
        @_request_concat_cache = {}
        @mgr.register-actor this
        # this context switch is important. if it is omitted, "action" method
        # will NOT be overwritten within the parent class
        # < ~ sleep 0 <= really no need for this?
        @action! if typeof! @action is \Function

    set-name: (name) ->
        @name = name
        @log.name = name

    subscribe: (routes) ->
        for route in unique flatten [routes]
            @subscriptions.push route

    unsubscribe: (route) ->
        @subscriptions.splice (@subscriptions.index-of route), 1

    send: (route, data) ~>
        if typeof! route isnt \String
            throw new TopicTypeError "Topic is not a string?", route
        enveloped = {from: @me, to: route, data, seq: @msg-seq++}
        @send-enveloped enveloped

    send-request: (opts, data, callback) ->
        # normalize parameters
        meta = {}

        # FIXME:
        # this timeout should be maximum 1000ms but when another blocking data
        # receive operation is taking place, this timeout is exceeded
        timeout = 30_000ms # longest duration
        # /FIXME

        if typeof! opts is \String
            meta.to = opts
        else
            meta.to = opts.topic or opts.route or opts.to
            timeout = that if opts.timeout

        seq = @msg-seq++
        request-id = "#{seq}"
        meta.part = @get-next-part-id opts.part, request-id

        meta.debug = yes if opts.debug

        if typeof! data is \Function
            # data might be null
            callback = data
            data = null

        enveloped = meta <<< {from: @me, seq, data, +req, timestamp: Date.now!}

        # make preperation for the response
        @subscribe meta.to

        part-handler = ->
        complete-handler = ->
        last-part-sent = no
        reg-part-handlers =
            on-part: (func) ~>
                part-handler := func
            on-receive: (func) ~>
                complete-handler := func
            send-part: (data, last-part=yes) ~>
                if last-part-sent
                    @log.err "Last part is already sent."
                    return
                msg = enveloped <<< {data}
                msg.part = @get-next-part-id (not last-part), request-id
                #@log.todo "Sending next part: ", msg
                @log.log "Sending next part with id: ", msg.part
                @send-enveloped msg
                if last-part
                    last-part-sent := yes

        do
            response-signal = new Signal {debug: enveloped.debug, name: "Req Sig:#{enveloped.seq}"}
            #@log.debug "Adding request id #{request-id} to request queue: ", @request-queue
            @request-queue[request-id] = response-signal
            error = null
            prev-pieces = {}
            message = {}
            merge-method-manual = no
            request-date = Date.now! # for debugging (benchmarking) purposes
            <~ :lo(op) ~>
                #@log.debug "Request timeout is: #{timeout}"
                err, msg <~ response-signal.wait timeout
                if err
                    #@log.err "We have timed out"
                    error := err
                    return op!
                else
                    #@log.debug "GOT RESPONSE SIGNAL in ", msg.timestamp - enveloped.timestamp
                    part-handler msg

                    if request-date?
                        if request-date + 1000ms < Date.now!
                            @log.debug "First response is too late for seq:#{enveloped.seq} latency:
                            #{Date.now! - request-date}ms"
                        request-date := undefined # disable checking

                    if msg.timeout
                        if enveloped.debug
                            @log.debug "New timeout is set from target: #{msg.timeout}
                                ms for request seq: #{enveloped.seq}"
                        timeout := msg.timeout
                    if msg.merge? and msg.merge is false
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

            if @_state.kill-finished
                @log.warn "Got response activity after killed?", error, message
                return
            if error is \timeout
                @log.warn "Request is timed out. Timeout was #{timeout}ms, seq: #{enveloped.seq}. req was:", enveloped
                #debugger
            # Got the full messages (or error) at this point.
            @unsubscribe meta.to
            #@log.debug "Removing request id: #{request-id}"
            delete @request-queue[request-id]

            if merge-method-manual
                error := "Merge method is set to manual. We can't concat the messages."
            #@log.log "Received full message: ", message
            complete-handler error, message
            if typeof! callback is \Function
                callback error, message
        if meta.debug => @log.debug "Sending request seq: #{enveloped.seq}"
        @send-enveloped enveloped
        return reg-part-handlers

    get-next-part-id: (autoinc, msg-id) ->
        next-part = undefined
        if autoinc
            unless @_partial_msg_states[msg-id]?
                @_partial_msg_states[msg-id] = 0
            next-part = @_partial_msg_states[msg-id]++
        else
            # single part message or last part of a partial message
            if @_partial_msg_states[msg-id]?
                # this is the last part of a parted message
                delete @_partial_msg_states[msg-id]
                next-part = LAST_PART
        return next-part

    send-response: (req, meta, data) ->
        unless req.req
            @log.err "No request is required, doing nothing."
            debugger
            return

        # normalize parameters
        if typeof! data is \Undefined
            data = meta
            meta = {}

        meta.part = @get-next-part-id meta.part, "#{req.from}.#{req.seq}"

        enveloped = {
            from: @me
            to: req.from
            seq: @msg-seq++
            data
            re: req.seq
            res-token: req.res-token
        } <<< meta


        if req.debug or meta.debug
            @log.debug "sending the response for request: ", enveloped
        @send-enveloped enveloped

    _inbox: (msg) ->
        #@log.log "Got message to inbox:", (JSON.stringify msg).length
        if @debug or msg.debug => @log.debug "Got msg to inbox: ", msg

        if @_state.kill-finished
            debugger

        msg.permissions = msg.permissions or []
        ####<~ sleep 0
        <~ set-immediate  # IMPORTANT: this fixes message sequences
        if msg.re? and message-owner(msg) is @me
            # this is a response to this actor.
            if @request-queue[msg.re]
                # this is a response
                if @debug
                    @log.debug "We were expecting this response: ", msg
                    @log.debug "Current request queue: ", @request-queue
                @request-queue[msg.re]?.go msg
            else
                @log.err "This is not a message we were expecting (or interested in)?
                     is it timed out already? I'm #{@me})", msg
                if @debug => @log.warn "Current request queue: ", @request-queue

            # Sink the messages here. Let only its request function handles the response.
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
                if msg.req and msg.part?
                    #@log.log "We received partial message, part: #{msg.part}"
                    @send-response msg, {+part, +ack}, null
                    request-id = "#{msg.from}.#{msg.seq}"

                    unless @_request_concat_cache[request-id]
                        @_request_concat_cache[request-id] = do ~>
                            message = {}
                            (msg) ~>
                                #@log.log "received a message to concatenate: ", msg
                                message `merge` msg
                                if msg.part is LAST_PART
                                    handler message
                                    delete @_request_concat_cache[request-id]
                    @_request_concat_cache[request-id] msg
                else
                    # simple message, forward as is
                    handler msg

        # for "trigger-topic" method to work
        @_route_handlers[][route].push handler


    trigger-topic: (route, ...args) ->
        if @_route_handlers[route]
            for handler in that
                handler ...args
        else
            @log.debug "No such route handler found: #{route}"

    once-topic: (route, handler) ->
        @subscribe route unless route in @subscriptions

        @once \data, (msg) ~>
            if msg.to `route-match` route
                handler msg
                @unsubscribe route

    send-enveloped: (msg) !->
        unless msg.to or (\auth of msg)
            debugger
            return @log.err "send-enveloped: Message has no route. Not sending.", msg
        <~ set-immediate
        unless msg.timestamp
            msg.timestamp = Date.now!
        if @debug => @log.debug "sending message: ", msg
        @mgr.distribute msg, @id

    kill: (reason) ->
        #@log.debug "Killing actor. reason: #{reason}"
        unless @_state.kill-started
            @_state.kill-started = yes
            @mgr.deregister-actor this
            for id, signal of @request-queue
                #@log.debug "...Removing signal: ", id
                signal.reset!
            @trigger \kill, reason
            @_state.kill-finished = yes

    on-every-login: (callback) ->
        @on-topic 'app.dcs.connect', (msg) ~>
            callback msg

        # request dcs login state on init
        @send-request 'app.dcs.update', (err, msg) ~>
            #@log.info "requesting app.dcs.connect state:"
            if not err and msg?data
                callback msg

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
