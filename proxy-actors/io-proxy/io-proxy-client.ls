require! '../../src/actor': {Actor}
require! '../../src/signal': {Signal}
require! '../../lib/sleep': {sleep}
require! '../../src/filters': {FpsExec}
require! '../../src/topic-match': {topic-match}
require! 'uuid4'


export class IoProxyClient extends Actor
    (opts={}) !->
        @route = opts.route or throw "route is required."
        @timeout = opts.timeout or 1000ms
        super @route
        @fps = new FpsExec (opts.fps or 20fps), this
        @reply-signal = new Signal \reply-signal
        @value = undefined

        @log.debug "Subscribed to @route: #{@route}, #{@me}"
        @on-topic "#{@route}.read", (msg) ~>
            @log.log "#{@route}.read received: ", msg
            if @reply-signal.waiting
                #@c-log "...is redirected to reply-signal..."
                @reply-signal.go msg.data
            else
                if msg.data.err
                    @trigger \error, {message: that}
                else
                    rec = msg.data?.res
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
            unless @route `topic-match` msg.data.routes
                @log.warn "We don't have a route for #{@route} in ", msg.data.routes

            @send-request {route: "#{@route}.update", @timeout}, (err, msg) ~>
                if err
                    @trigger \error, {message: err}
                else
                    #console.warn "received update route: ", msg
                    @trigger-topic "#{@route}.read", msg

        # check if app is logged in
        <~ sleep ((Math.random! * 200ms) + 100ms )
        err, msg <~ @send-request "app.dcs.update"
        unless err
            if msg.data is yes
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
        route = "#{@route}.write"
        err, msg <~ @send-request {route, timeout: @timeout}, {val: value}
        error = err or msg?.data.err
        if typeof! callback is \Function
            callback error
