require! 'aea': {sleep}

export class FpsExec
    (fps=20fps) ->
        @period = 1000ms / fps
        @timer = null
        @last-sent = 0

    now: ->
        new Date! .get-time!

    exec: (func, ...args) ->

        # TODO: this part of code is nearly the same as
        # @exec-context's body. Remove duplicate code.

        try
            # do not send repetative messages in the time window
            if @now! > @last-sent + @period
                @last-sent = @now!
                # ready to send
            else
                clear-timeout @timer
        @timer = sleep @period, ->
            func.apply this, args


    exec-context: (context, func, ...args) ->
        try
            # do not send repetative messages in the time window
            if @now! > @last-sent + @period
                @last-sent = @now!
                # ready to send
            else
                clear-timeout @timer
        @timer = sleep @period, ->
            func.apply context, args
