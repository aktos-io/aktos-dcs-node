require! '../../src/actor': {Actor}
require! '../../src/signal': {Signal}
require! '../../lib/sleep': {sleep}
require! '../../src/filters': {FpsExec}


export class IoProxyClient extends Actor
    (opts={}) ->
        @topic = opts.topic or throw "Topic is required."
        @timeout = opts.timeout or 1000ms
        super @topic
        @fps = new FpsExec (opts.fps or 20fps), this
        @reply-signal = new Signal \reply-signal

        # handle realtime events
        #@actor = new RactiveActor this, name=topic

        @on-topic "#{@topic}.read", (msg) ~>
            #@log.log "#{@topic}.read received: ", msg
            if @reply-signal.waiting
                #@c-log "...is redirected to reply-signal..."
                @reply-signal.go msg.payload
            else
                if msg.payload?
                    '''
                    # if has no payload, then it probably comes from
                    # another actor's request-update!
                    # FIXME: this shouldn't receive the other actors'
                    # update messages in the first place.
                    '''
                    if msg.payload.err
                        @trigger \error, {message: that}
                    else
                        try
                            @trigger \read, msg.payload.res
                        catch
                            @trigger \error, {message: e}

        @on-topic "app.logged-in", ~>
            @send-request {topic: "#{@topic}.update", timeout: @timeout}, (err, msg) ~>
                if err
                    @trigger \error, {message: err}
                else
                    #console.warn "received update topic: ", msg
                    @trigger-topic "#{@topic}.read", msg

        # check if app is logged in
        <~ sleep ((Math.random! * 200ms) + 100ms )
        err, msg <~ @send-request "app.logged-in.update"
        unless err
            if msg.payload is yes
                @log.log "triggering app.logged-in on render."
                @trigger-topic 'app.logged-in'


    write: (...args) ->
        @fps.exec ~> @filtered-write ...args

    filtered-write: (value, callback) ->
        topic = "#{@topic}.write"
        @send topic, {val: value}
        @reply-signal.clear!
        _err, data <~ @reply-signal.wait @timeout
        err = _err or data?.err
        unless err
            try clear-timeout x
            @trigger \read, {curr: value, prev: undefined}
        else
            @trigger \error, {message: err}

        if typeof! callback is \Function
            callback err
