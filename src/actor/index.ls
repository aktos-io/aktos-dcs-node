require! '../../lib': {sleep, pack, EventEmitter, Logger, merge}
require! '../../lib/debug-tools': {brief}
require! './actor-manager': {ActorManager}
require! '../signal': {Signal}
require! 'prelude-ls': {split, flatten, keys, unique, is-it-NaN}
require! '../topic-match': {topic-match: route-match}
require! './request'

export class TopicTypeError extends Error
    (@message, @route) ->
        super ...
        Error.captureStackTrace(this, TopicTypeError)
        @type = \TopicTypeError


LAST_PART = -1
message-owner = (.to.split '.' .[*-1])  # last part of "to:" attribute

export class Actor extends EventEmitter implements request
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
        @_last_login = 0
        @mgr.register-actor this
        # this context switch is important. if it is omitted, "action" method
        # will NOT be overwritten within the parent class
        # < ~ sleep 0 <= really no need for this?
        @once-topic 'app.dcs.connect', (msg) ~>
            # log first login
            @_last_login = Date.now!
        @action! if typeof @action is \function

    set-name: (name) ->
        @name = name
        @log.name = name

    subscribe: (routes) ->
        for route in flatten [routes]
            if route not in @subscriptions
                @subscriptions.push route

    unsubscribe: (route) ->
        @subscriptions.splice (@subscriptions.index-of route), 1

    send: (route, data) ~>
        if typeof! route is \String
            route = {to: route}

        enveloped = {from: @me, data, seq: @msg-seq++} <<< route
        @send-enveloped enveloped

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

    _inbox: (msg) ->
        #@log.log "Got message to inbox:", (JSON.stringify msg).length
        if @debug or msg.debug => @log.debug "Got msg to inbox: ", brief msg

        if @_state.kill-finished
            debugger

        msg.permissions = msg.permissions or []
        <~ set-immediate  # IMPORTANT: this fixes message sequences
        if msg.re? and message-owner(msg) is @me
            # this is a response to this actor.
            if @request-queue[msg.re]
                # this is a response
                if @debug or msg.debug
                    @log.debug "We were expecting this response: ", msg
                    @log.debug "Current request queue: ", keys @request-queue
                @request-queue[msg.re]?.go null, msg
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
                                    try
                                        handler.call this, message
                                    catch 
                                        @log.warn "#{route} handler has an uncaught exception: #{e}"
                                        @send-response msg, {error: "Uncaught exception: #{e}"}
                                    delete @_request_concat_cache[request-id]
                    @_request_concat_cache[request-id] msg
                else
                    # simple message, forward as is
                    try
                        handler.call this, msg
                    catch 
                        @log.warn "#{route} handler has an uncaught exception: #{e}"
                        @send-response msg, {error: "Uncaught exception: #{e}"}

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
            return @log.err "send-enveloped: Message has no route or has no auth key. Not sending.", msg
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
                delete @request-queue[id]
            @trigger \kill, reason
            @killed = true
            @_state.kill-finished = yes

    on-every-login: (opts, callback) ->
        if typeof! opts is \Function 
            callback = opts 
            opts = {
                window: 1000ms # fire on registration if last_login is within this window
            }        
        #@log.debug "Registering on-every-login callback."

        # Call the function on every 'app.dcs.connect' message
        @on-topic 'app.dcs.connect', (msg) ~>
            #@log.debug "calling the registered on-every-login callback"
            callback msg
            @_last_login = Date.now!

        # Request a login status on registration, call the function if we are connected.
        @send-request 'app.dcs.update', (err, msg) ~>
            #@log.debug "requesting app.dcs.connect state:"
            if not err and msg?data
                if @_last_login + opts.window <= Date.now!
                    callback msg
                    @_last_login = Date.now!

    trigger-login: -> 
        @trigger \app.dcs.connect


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
