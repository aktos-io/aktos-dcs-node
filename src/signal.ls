require! '../lib': {sleep}
require! 'uuid4'
require! 'prelude-ls': {is-it-NaN}

export class Signal
    ->
        @name = uuid4!
        @reset!

    fire: (event, ...args) ->
        #@log.log "trying to fire..."
        if @waiting and @should-run
            #@log.log "signal fired!"
            @waiting = no
            @should-run = no
            for callback in @callbacks
                try clear-timeout @timer
                callback.handler.apply callback.ctx, ([event?.reason] ++ args)
            @callbacks = []


    wait: (timeout, callback) ->
        # usage:
        #   .wait [timeout,] callback
        #

        # re-arrange arguments
        if typeof! timeout is \Function
            callback = timeout
            timeout = 0
        # /re-arrange arguments


        if callback.to-string! not in [..handler.to-string! for @callbacks]
            @callbacks.push {ctx: this, handler: callback}
        @waiting = yes

        unless is-it-NaN timeout
            if timeout > 0
                @timeout = timeout
                @reset-timeout!

        # try to run signal if it is set as `go` before reaching "wait" line
        @fire!

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
        @fire.apply this, ([null] ++ args)

    reset: ->
        @callbacks = []
        @should-run = no
        @waiting = no
        try clear-timeout @timer
        @timer = void
        @skip-next = no

    reset-timeout: (duration) ->
        @timeout = duration if duration > 0
        try clear-timeout @timer
        @timer = sleep @timeout, ~>
            @should-run = yes
            @fire {reason: \timeout}

    heartbeat: (x) ->
        @reset-timeout x
