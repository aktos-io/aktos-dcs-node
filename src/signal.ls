require! 'aea': {sleep}
require! 'aea/debug-log': {logger}
require! 'uuid4'

export class Timeout
    ->
        @name = uuid4!
        @callbacks = []
        @should-run = no
        @waiting = no
        @timer = void
        #@log = new logger @name

    fire: (...args) ->
        #@log.log "trying to fire..."
        if @waiting and @should-run
            #@log.log "signal fired!"
            @waiting = no
            @should-run = no
            for callback in @callbacks
                reason = if @timer is null then \timeout else \hasevent
                try clear-timeout @timer
                callback.apply this, ([reason] ++ args)


    wait: (timeout, callback) ->
        # usage:
        #   .wait [timeout,] callback
        #
        #@log.log "started waiting..."
        if typeof! timeout is \Function
            timeout = void
            callback = timeout

        if callback.to-string! not in [..to-string! for @callbacks]
            @callbacks.push callback
        @waiting = yes

        if timeout
            @timeout = timeout
            @reset!

        # try to run signal if it is set as `go` before reaching "wait" line
        @fire!


    go: (...args) ->
        #@log.log "called 'go!'"
        @should-run = yes
        @fire.apply this, args

    reset: ->
        try clear-timeout @timer
        @timer = sleep @timeout, ~>
            @should-run = yes
            @fire!
