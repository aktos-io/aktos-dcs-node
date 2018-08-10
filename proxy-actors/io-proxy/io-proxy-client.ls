require! '../../src/actor': {Actor}
require! '../../src/signal': {Signal}
require! '../../lib/sleep': {sleep}
require! '../../src/filters': {FpsExec}
require! '../../src/topic-match': {topic-match}

_x = 0
uuid4 = -> "some-random-#{_x++}"
#require! 'uuid4'


export class IoProxyClient extends Actor
    (opts={}) !->
        @route = opts.route or throw "route is required."
        @timeout = opts.timeout or 1000ms
        super @route
        @fps = new FpsExec (opts.fps or 20fps), this
        @value = undefined
        @last-update = 0

        #@log.debug "Subscribed to @route: #{@route}, #{@me}"
        @on-topic "#{@route}", (msg) ~>
            #@log.log "#{@route}.write received: ", msg
            if msg.data.err
                @trigger \error, {message: that}
            else
                value = msg.data.val
                if JSON.stringify(value) isnt JSON.stringify(@value)
                    @trigger \change, value
                    if typeof! value is \Boolean
                        # detect edge
                        if @value is off and value is on
                            @trigger \r-edge
                        if @value is on and value is off
                            @trigger \f-edge

                @last-update = Date.now!
                @value = value
                @trigger \read, value, msg

        update = (callback) ~>
            unless callback then callback = (->)
            err, msg <~ @send-request {route: "#{@route}"}, {+update}
            if err or msg.err
                @trigger \error, {message: err}
                callback err
            else
                #console.warn "received update route: ", msg
                @trigger-topic "#{@route}", msg
                callback null

        @on-every-login (msg) ~>
            #@log.debug "Seems logged in right now."
            <~ :lo(op) ~>
                err <~ update
                if err
                    @log.warn "Update error, retrying..."
                    <~ sleep 1000ms
                    lo(op)
                else
                    return op!


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
                <~ set-immediate  # !important!
                callback value
                @cancel name

    write: (value, callback) !->
        @fps.exec ~>
            @fps.pause!
            @filtered-write value, (...args) ~>
                @fps.resume!
                if callback?
                    that ...args

    read: (callback) !->
        err, msg <~ @send-request {route: "#{@route}"}, {+read}
        callback err, msg

    filtered-write: (value, callback) !->
        err, msg <~ @send-request {route: "#{@route}"}, {val: value}
        error = err or msg?.data.err
        unless err
            #@log.debug "Write succeeded."
            @value = msg.data.res
        if typeof! callback is \Function
            callback error
