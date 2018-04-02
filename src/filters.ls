require! '../lib': {sleep}

export class FpsExec
    (fps=20fps, @context) ~>
        @period = 1000ms / fps
        @timer = null
        @last-sent = 0
        @immediate = yes

    now: ->
        new Date! .get-time!

    exec: (func, ...args) ->
        # do not send repetative messages in the time window
        if @now! > @last-sent + @period
            @last-sent = @now!
            # ready to send
        else
            # wasn't ready to send as we received a new execution,
            # drop the previous one
            @immediate = no
            try clear-timeout @timer
        @timer = sleep (if @immediate => 0 else @period), ~>
            @immediate = yes
            func.call @context, ...args
