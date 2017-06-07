require! 'aea': {sleep}

export class FpsExec
    ->
        @period = 1000ms / 30fps
        @timer = null
        @last-sent = 0

    now: ->
        new Date! .get-time!

    exec: (func, ...args) ->
        try
            # do not send repetative messages in the time window
            if @now! > @last-sent + @period
                @last-sent = @now!
                # ready to send
            else
                clear-timeout @timer
        @timer = sleep @period, ->
            func.apply this, args
