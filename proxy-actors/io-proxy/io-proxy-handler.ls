require! '../../src/actor': {Actor}
require! '../../lib/event-emitter': {EventEmitter}
require! '../../lib/sleep': {sleep}
require! '../../lib/logger': {Logger}
require! '../../src/errors': {CodingError}
require! '../../lib/memory-map': {IoHandle}

require! 'prelude-ls': {find}

class SingularDriver
    (@driver) ->
        @busy = no
        @log = new Logger \sing.
        @queue = []
        @max-busy = 100ms

    run: (method, ...args, callback) !->
        if @busy
            #@log.info "busy! adding to queue."
            @queue.push [method, args, callback]
            return
        #@log.log "we are now going busy, args: ", ...args
        @busy = yes
        x = sleep @max-busy, ~>
            @log.warn "FORCE RUNNNING NEXT!"
            @next!
        @driver[method] ...args, (...ret) ~>
            if x
                clear-timeout x
                callback ...ret
                #@log.log "we are free"
                @next!
            else
                @log.err "what happened here?"

    next: ->
        @busy = no
        if @queue.length > 0
            #@log.info "Running from queue"
            next = @queue.shift!
            @run next.0, ...next.1, next.2

    read: (...args, callback) ->
        @run \read, ...args, callback

    write: (...args, callback) ->
        @run \write, ...args, callback

class LineUp
    @drivers = []
    (driver) ->
        if find (.driver is driver), @@drivers
            #console.log "Returning exitsting singular driver for: ", driver
            return that.driver
        else
            #console.log "Initialized new Lined up driver for: ", driver
            #singular = new SingularDriver driver
            @@drivers.push {driver}
            return driver


export class IoProxyHandler extends Actor
    (handle, _route, driver) ->
        if not driver
            driver = _route
            _route = null
            unless handle?.constructor?.name is \IoHandle
                throw new CodingError "handle should be an instance of IoHandle class"
        else
            # handle is an object to convert into an IoHandle instance
            handle = new IoHandle handle, _route

        route = handle.route
        route or throw new CodingError "A route MUST be provided to IoProxyHandler."
        super route
        #@log.info "Initializing #{handle.route}"

        prev = null
        age = 0
        broadcast-value = (err, value) ~>
            #@log.log "Broadcasting err: ", err , "value: ", value
            @send "#{@name}", {err, val: value}
            if not err and value isnt prev
                #@log.log "Store previous (broadcast) value (from #{prev} to #{curr})"
                prev := value
                age := Date.now!

        response-value = (msg) ~>
            (err, value) ~>
                @send-response msg, {err, val: value}
                if not err and value isnt prev
                    #@log.log "Store previous (resp.) value (from #{prev} to #{curr})"
                    prev := value
                    age := Date.now!

        if driver?
            safe-driver = new LineUp driver
            # assign handlers internally
            @on \read, (handle, respond) ~>
                #console.log "requested read!"
                err, value <~ safe-driver._safe_read handle
                #console.log "responding read value: ", err, value
                respond err, value

            @on \write, (handle, value, respond) ~>
                #console.log "requested write for #{handle.address}, value: ", value
                err <~ safe-driver.write handle, value
                #console.log "write error status: ", err
                respond err

            # driver decides whether to watch changes of this handle or not.
            driver.watch-changes handle, broadcast-value

        @on-topic "#{@name}", (msg) ~>
            if \val of msg.data
                #@log.debug "triggering 'write'."
                new-value = msg.data.val
                @trigger \write, handle, new-value, (err) ~>
                    meta = {cc: "#{@name}"}
                    data = {err}
                    unless err
                        #@log.debug "write succeeded, broadcast the value"
                        data.val = new-value
                        prev := new-value
                    @send-response msg, meta, data
            else if \update of msg.data
                # send response directly to requester
                #@log.debug "update requested."

                max-age = 10min * 60_000_ms_per_min
                if max-age + age < Date.now!
                    #@log.debug "...value is too old, reading again."
                    @trigger \read, handle, response-value(msg)
                else
                    #@log.debug "...value is fresh, responding from cache."
                    response-value(msg) err=null, value=prev
            else
                # consider this a read
                # send response directly to requester
                #@log.warn "triggering 'read' because update requested."
                @trigger \read, handle, response-value(msg)

        @on-every-login (msg) ~>
            # broadcast the status
            #@log.warn "triggering broadcast 'read' because we are logged in."
            @trigger \_try_broadcast_state

        driver.on \connect, ~>
            #@log.info "Driver is connected, broadcasting current status"
            @trigger \_try_broadcast_state


        driver.on \disconnect, ~>
            #@log.info "Driver is disconnected, publish the error"
            broadcast-value err="Target is disconnected."

        @on '_try_broadcast_state', ~>
            if driver.connected
                @trigger \read, handle, broadcast-value
            else
                @log.info "Driver is not connected, skipping broadcasting."
