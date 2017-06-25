require! 'aea': {sleep}
require! 'aea/debug-log': {logger}
require! 'uuid4'

export class Signal
    ->
        @name = uuid4!
        @callbacks = []
        @should-run = no
        @waiting = no
        @timer = void
        #@log = new logger @name
        @skip-next = no

    fire: (event, ...args) ->
        #@log.log "trying to fire..."
        if @waiting and @should-run
            #@log.log "signal fired!"
            @waiting = no
            @should-run = no
            for callback in @callbacks
                try clear-timeout @timer
                callback.handler.apply callback.ctx, ([event.reason] ++ args)


    wait: (timeout, callback) ->
        # usage:
        #   .wait [timeout,] callback
        #

        # re-arrange arguments
        if typeof! timeout is \Function
            callback = timeout
        # /re-arrange arguments


        if callback.to-string! not in [..to-string! for @callbacks]
            @callbacks.push {ctx: this, handler: callback}
        @waiting = yes

        if typeof! timeout is \Number
            @timeout = timeout
            @reset-timeout!

        # try to run signal if it is set as `go` before reaching "wait" line
        @fire {reason: \hasevent}

    skip-next-go: ->
        @skip-next = yes

    clear: ->
        @should-run = no

    go: (...args) ->
        if @skip-next
            @skip-next = no
            return

        #@log.log "called 'go!'"
        @should-run = yes
        @fire.apply this, ([{reason: \hasevent}] ++ args)

    reset-timeout: ->
        try clear-timeout @timer
        @timer = sleep @timeout, ~>
            @should-run = yes
            @fire {reason: \timeout}
