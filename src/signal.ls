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
    (opts={}) ->
        if opts.debug
            @debug = yes
        @name = arguments.callee.caller.name
        @log = new Logger @name
        @reset!

    reset: ->
        # clear everything like the object is
        # initialized for the first time
        @[]callbacks.splice(0, @callbacks.length)
        @go-params = []
        @should-run = no
        @waiting = no
        try clear-timeout @timer
        @timer = void
        @skip-next = no

    fire: (error) ->
        #@log.log "trying to fire..."
        if @waiting and @should-run
            params = @go-params
            #@log.log "signal fired with params:", params
            for let callback in @callbacks
                <~ sleep 0
                callback.handler.call callback.ctx, error?.reason, ...params
            # empty the callbacks
            @reset!


    wait: (timeout, callback) ->
        # normalize arguments
        if typeof! timeout is \Function
            callback = timeout
            timeout = 0

        if callback.to-string! not in [..handler.to-string! for @callbacks]
            if @debug => @log.debug "...adding this callback"
            @callbacks.push {ctx: this, handler: callback}
        else
            if @debug
                @log.debug "this callback seems to be registered already"
                console.log @callbacks

        @waiting = yes
        unless is-it-NaN timeout
            if timeout > 0
                @timeout = timeout
                if @debug => @log.info "Heartbeating! timeout: #{@timeout}"
                @heartbeat!

        # try to run signal in case of it is let `go` before reaching "wait" line
        if @should-run
            @fire!

    skip-next-go: ->
        @skip-next = yes

    clear: ->
        @should-run = no

    go: (...args) ->
        if @skip-next
            @skip-next = no
            return
        @should-run = yes
        @go-params = args
        #@log.log "called 'go!'" #, @go-params
        @fire!

    heartbeat: (duration) ->
        #@log.log "Heartbeating..........."
        if duration > 0
            #@log.log "setting new timeout: #{duration}"
            @timeout = duration
        try clear-timeout @timer
        @timer = sleep @timeout, ~>
            @should-run = yes
            #@log.log "firing with timeout! timeout: #{@timeout}"
            @fire {reason: \timeout}
