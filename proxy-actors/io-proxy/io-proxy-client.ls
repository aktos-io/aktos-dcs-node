require! '../../src/actor': {Actor}
require! '../../src/signal': {Signal}
require! '../../lib/sleep': {sleep}
require! '../../src/filters': {FpsExec}
require! '../../src/topic-match': {topic-match}
require! 'uuid4'


export class IoProxyClient extends Actor
    (opts={}) !->
        @topic = opts.topic or throw "Topic is required."
        @timeout = opts.timeout or 1000ms
        super @topic
        @fps = new FpsExec (opts.fps or 20fps), this
        @reply-signal = new Signal \reply-signal
        @value = undefined

        @on-topic "#{@topic}.read", (msg) ~>
            #@log.log "#{@topic}.read received: ", msg
            if @reply-signal.waiting
                #@c-log "...is redirected to reply-signal..."
                @reply-signal.go msg.payload
            else
                if msg.payload.err
                    @trigger \error, {message: that}
                else
                    rec = msg.payload.res
                    @trigger \read, rec
                    # detect change
                    if rec.curr isnt @value
                        @trigger \change, rec.curr
                        if @value is off and rec.curr is on
                            @trigger \r-edge
                        if @value is on and rec.curr is off
                            @trigger \f-edge
                        @value = rec.curr

        @on-topic "app.dcs.connect", (msg) ~>
            unless @topic `topic-match` msg.payload.permissions.rw
                @log.warn "We don't have write permissions for #{@topic}"

            @send-request {topic: "#{@topic}.update", timeout: @timeout}, (err, msg) ~>
                if err
                    @trigger \error, {message: err}
                else
                    #console.warn "received update topic: ", msg
                    @trigger-topic "#{@topic}.read", msg

        # check if app is logged in
        <~ sleep ((Math.random! * 200ms) + 100ms )
        err, msg <~ @send-request "app.dcs.update"
        unless err
            if msg.payload is yes
                @log.log "triggering app.dcs.connect on initialization.",
                @trigger-topic 'app.dcs.connect', msg

    r-edge: (callback) !->
        @once \r-edge, callback

    f-edge: (callback) !->
        @once \f-edge, callback

    when: (filter-func, callback) !->
        name = uuid4!
        #console.log "adding 'when' with name: #{name}"
        @on \change, name, (value) ~>
            #console.log "#{name}: comparing with value: #{value}"
            if filter-func value
                #console.log "...passed from filter function: #{value}"
                <~ sleep 0  # !important!
                callback value
                @cancel name

    write: (value, callback) !->
        @fps.exec ~> @filtered-write value, callback

    filtered-write: (value, callback) !->
        topic = "#{@topic}.write"
        err, msg <~ @send-request {topic, timeout: @timeout}, {val: value}
        error = err or msg?.payload.err
        if typeof! callback is \Function
            callback error
