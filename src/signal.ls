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
        @name = opts.name or arguments.callee.caller.name
        @log = new Logger @name
        @response = []
        @callback = {ctx: null, handler: null}
        if @debug => @log.debug "Initialized new signal."
        @reset!

    reset: ->
        # clear everything like the object is
        # initialized for the first time
        delete @callback.handler
        delete @callback.ctx
        @should-run = no
        @waiting = no
        try clear-timeout @timer
        @timer = void
        @skip-next = no

    fire: (error) ->
        #@log.log "trying to fire..."
        return if typeof! @callback?.handler isnt \Function
        params = unless error then @response else []
        @error = error?.reason
        {handler, ctx} = @callback
        if @debug => @log.debug "signal is being fired with err: ", @error, "res: ", ...params
        due-date = Date.now!
        err = @error
        @reset!
        set-immediate ~>
            handler.call ctx, err, ...params
            if @debug => @log.debug "signal is actually fired."
            if Date.now! - due-date > 100ms
                @log.warn "System seems busy now? Actual firing took place after #{Date.now! - due-date}ms"

    wait: (timeout, callback) ->
        # normalize arguments
        if typeof! timeout is \Function
            callback = timeout
            timeout = 0
        if @waiting
            console.error "We were waiting already. Why hit here?"
            return
        @error = \UNFINISHED

        #if @debug => @log.debug "...adding this callback"
        @callback = {ctx: this, handler: callback}
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
        @response = args
        #@log.log "called 'go!'" , @response
        if @waiting
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
            if @waiting
                @fire {reason: \timeout}


export class SignalBranch
    (opts={}) ->
        @timeout = opts.timeout or -1
        @count = 0
        @main = new Signal
        @signals = []
        @error = null

    add: (opts) ->
        timeout = opts?timeout or @timeout
        name = opts?name or "#{@count}"
        #console.log "........signal branch adding: #{name} with timeout #{timeout}"
        signal = new Signal {name}
        @signals.push signal
        @count++
        signal.wait timeout, (err) ~>
            #console.log "==== signal is moving, count: #{@count}"
            if err
                @error = that
            if --@count is 0
                #console.log "+++++letting main go."
                @main.go @error

        return signal

    joined: (callback) ->
        @main.wait @timeout, (err) ~>
            for @signals => ..clear!
            callback err, @signals


if require.main is module
    log = new Logger \test
    branch = new SignalBranch timeout: 2000ms
    for let index, content of <[ hello there foo bar ]>
        timeout = 1000 + index * Math.random! * 1000
        log.log "new branch named #{content} at #{index} with #{timeout}ms timeout"
        s = branch.add {timeout, name: content}
        <~ sleep (timeout - 20)
        log.log "joining branch named: #{index}"
        s.go content
    err, signals <~ branch.joined
    log.log "all signals are joined. err: ", err
    for signals
        console.log "#{..name}: err: ", ..error, "res: ", ..response
