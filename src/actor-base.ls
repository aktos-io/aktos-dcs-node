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
        @id = @actor-id
        @name = @name or @actor-id
        @log = new logger @name

        @event-handlers = {}

        @msg-seq = 0
        <~ sleep 0
        @post-init!

    post-init: ->

    on: (event, handler) ->
        # usage:
        # @on 'my-event', (param) ->
        #
        # or
        #
        # @on {
        #     'my-event': (param) ->
        # }
        handlers = @event-handlers
        add-handler = (name, handler) ~>
            if handlers[name] is undefined
                handlers[name] = [handler]
            else
                handlers[name].push handler

        if typeof! event is \String
            return if (check handler) is \failed
            add-handler event, handler
        else if typeof! event is \Object
            for _ev, handler of event
                return if (check handler) is \failed
                add-handler _ev, handler

    trigger: (name, ...args) ->
        if @event-handlers[name]
            for handler in @event-handlers[name]
                handler.apply this, args

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
