require! '../lib': {sleep}

export class FpsExec
    (opts=20fps) ~>
        fps = if typeof! opts is \Number => opts
        @debug = (try opts.debug)
        @period = opts.period or (1000ms / fps)
        @timer = null
        @last-exec = 0

    now: ->
        new Date! .get-time!

    exec: (func, ...args) ->
        # do not send repetative messages in the time window
        time-to-exec = @period - (@now! - @last-exec)
        if time-to-exec < 0
            time-to-exec = 0
        try
            clear-timeout @timer
            if @debug => console.info "FpsExec is skipping an execution."
        @timer = sleep time-to-exec, ~>
            func ...args
            @last-exec = @now!


/*
x = new FpsExec 15fps
# or
x = new FpsExec period: 3000ms

### Example Output:

[13:39:26.587] DbLogger        : Read something:  10487
[13:39:27.089] DbLogger        : Read something:  10488
[13:39:27.590] DbLogger        : Read something:  10489
[13:39:28.087] DbLogger        : This is going to be recorded:  10489
[13:39:28.091] DbLogger        : Read something:  10490
[13:39:28.591] DbLogger        : Read something:  10491
[13:39:29.092] DbLogger        : Read something:  10492
[13:39:29.593] DbLogger        : Read something:  10493
[13:39:30.091] DbLogger        : This is going to be recorded:  10493
[13:39:30.093] DbLogger        : Read something:  10494
[13:39:30.594] DbLogger        : Read something:  10495
[13:39:31.094] DbLogger        : Read something:  10496
[13:39:31.593] DbLogger        : Read something:  10497
[13:39:32.093] DbLogger        : This is going to be recorded:  10497
[13:39:32.096] DbLogger        : Read something:  10498
[13:39:32.597] DbLogger        : Read something:  10499
[13:39:33.098] DbLogger        : Read something:  10500
[13:39:33.598] DbLogger        : Read something:  10501
[13:39:34.096] DbLogger        : This is going to be recorded:  10501
[13:39:34.099] DbLogger        : Read something:  10502
[13:39:34.599] DbLogger        : Read something:  10503
[13:39:35.100] DbLogger        : Read something:  10504
[13:39:35.601] DbLogger        : Read something:  10505
[13:39:36.099] DbLogger        : This is going to be recorded:  10505
*/
