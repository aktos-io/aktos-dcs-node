require! '../lib': {sleep, Logger}
require! 'uuid4'
require! 'prelude-ls': {is-it-NaN}

'''

# Methods

signal.wait [timeout:int::milliseconds,] callback
---------------------------------------------------------
Waits for `signal.go` to call the `callback`.

`callback` signature: (err[, value:any[, value2:any, ...]])
If `timeout` is defined, err is set to a truthy value at the
end of the timeout.

signal.go [value:any[, value2:any, ...]]
---------------------------------------------------------
'''

export class Signal
    ->
        @name = arguments.callee.caller.name
        @log = new Logger @name
        @reset!

    reset: ->
        # clear everything like the object is
        # initialized for the first time
        @callbacks = []
        @should-run = no
        @waiting = no
        try clear-timeout @timer
        @timer = void
        @skip-next = no

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
                @heartbeat!

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
        @fire.call this, null, ...args


    heartbeat: (duration) ->
        @timeout = duration if duration > 0
        try clear-timeout @timer
        @timer = sleep @timeout, ~>
            @should-run = yes
            @fire {reason: \timeout}


    # -------------------
    # Deprecated methods
    # -------------------
    reset-timeout: (duration) ->
        @log.warn "reset-timeout method is deprecated, use heartbeat instead."
        @heartbeat duration
