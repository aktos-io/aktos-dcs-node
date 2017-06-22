require! 'uuid4'
require! 'aea': {sleep, logger, debug-levels}
require! 'prelude-ls': {empty}

export class ActorBase
    (@name) ->
        @actor-id = uuid4!
        @log = new logger (@name or @actor-id)

        @receive-handlers = []
        @update-handlers = []
        @msg-seq = 0
        <~ sleep 0
        @post-init!

    post-init: ->

    on-receive: (handler) ->
        @log.section \debug1, "adding handler to run on-receive..."
        if typeof! handler isnt \Function
            @log.err "parameter passed to 'on-receive' should be a function."
            return
        @receive-handlers.push handler

    receive: ->
        ...

    on-update: (handler) ->
        if typeof! handler isnt \Function
            @log.err "parameter passed to 'on-receive' should be a function."
            return
        @update-handlers.push handler

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
            # if there is an update handler, let this handler handle the
            # update messages.
            if \update of msg and not empty @update-handlers
                for handler in @receive-handlers
                    handler.call this, msg
            else
                for handler in @receive-handlers
                    @log.section \recv-debug, "firing receive handler..."
                    handler.call this, msg
        catch
            @log.err "problem in handler: ", e
