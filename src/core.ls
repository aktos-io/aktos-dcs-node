require! 'uuid4'
require! 'aea': {sleep, logger, debug-levels}
require! 'prelude-ls': {empty}


check = (handler) ->
    if typeof! handler isnt \Function
        console.error "ERR: parameter passed to 'on-receive' should be a function."
        return \failed

export class ActorBase
    (@name) ->
        @actor-id = uuid4!
        @log = new logger (@name or @actor-id)

        @receive-handlers = []
        @update-handlers = []
        @data-handlers = []

        @msg-seq = 0
        <~ sleep 0
        @post-init!

    post-init: ->

    on-receive: (handler) ->
        return if (check handler) is \failed
        @receive-handlers.push handler

    on-update: (handler) ->
        return if (check handler) is \failed
        @update-handlers.push handler

    on-data: (handler) ->
        return if (check handler) is \failed
        @data-handlers.push handler

    get-msg-template: ->
        msg-raw =
            sender: void # will be sent while sending
            timestamp: Date.now! / 1000
            msg_id: @msg-seq++
            topic: void
            token: void

    _inbox: (msg) ->
        # process one message at a time
        try
            if \update of msg
                for handler in @update-handlers
                    handler.call this, msg
            if \payload of msg
                for handler in @data-handlers
                    handler.call this, msg

            # deliver every message to receive-handlers 
            for handler in @receive-handlers
                @log.section \recv-debug, "firing receive handler..."
                handler.call this, msg
        catch
            @log.err "problem in handler: ", e
