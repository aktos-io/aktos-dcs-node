require! 'uuid4'
require! 'aea': {sleep, logger, debug-levels, merge}
require! 'prelude-ls': {empty}


check = (handler) ->
    if typeof! handler isnt \Function
        console.error "ERR: parameter passed to 'on-receive' should be a function."
        return \failed

export class ActorBase
    (@name) ->
        @actor-id = uuid4!
        @log = new logger (@name or @actor-id)

        @event-handlers = {}

        @msg-seq = 0
        <~ sleep 0
        @post-init!

    post-init: ->

    on: (event, handler) ->
        # usage:
        # @on 'my-event', (param) -> /**/
        #
        # or
        #
        # @on {
        #     'my-event': (param) -> /**/
        # }
        return if (check handler) is \failed
        handlers = @event-handlers
        add-handler = (name, handler) ~>
            if handlers[name] is undefined
                handlers[name] = [handler]
            else
                handlers[name].push handler

        if typeof! event is \String
            add-handler event, handler
        else if typeof! event is \Object
            for _ev, handler of evet
                add-handler _ev, handler

    trigger: (name, ...args) ->
        if @event-handlers[name]
            for handler in @event-handlers[name]
                handler.apply this, args


    on-receive: (handler) ->
        @on \receive, handler

    on-update: (handler) ->
        @on \update, handler

    on-data: (handler) ->
        @on \data, handler

    msg-template: (msg) ->
        @get-msg-template msg

    get-msg-template: (msg) ->
        # deprecated, use @msg-template function instead
        msg-raw =
            sender: void # will be sent while sending
            timestamp: Date.now! / 1000
            msg_id: @msg-seq++
            topic: void
            token: void

        if msg
            return msg-raw <<<< msg
        else
            return msg-raw

    _inbox: (msg) ->
        # process one message at a time
        try
            if \update of msg
                @trigger \update, msg
            if \payload of msg
                @trigger \data, msg
            # deliver every message to receive-handlers
            @trigger \receive, msg
        catch
            @log.err "problem in handler: ", e
