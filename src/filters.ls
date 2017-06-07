export class FpsExec
    ->
        @last-sent = 0
        @period = 1000ms / 60fps

    now: ->
        new Date! .get-time!

    _call: (context, func, ...args) ->
        if @now! > @last-sent + @period
            @last-sent = @now!
            # ready to send
            console.log "ready to exec..."
            func.apply context, args
