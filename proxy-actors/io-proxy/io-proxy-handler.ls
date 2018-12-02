require! '../../src/actor': {Actor}
require! '../../lib/event-emitter': {EventEmitter}
require! '../../lib/sleep': {sleep}
require! '../../lib/logger': {Logger}
require! '../../src/errors': {CodingError}
require! '../../lib/memory-map': {IoHandle}

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

        unless driver
            throw new CodingError "Driver must be provided"

        unless route=(handle.route)
            throw new CodingError "A route MUST be provided to IoProxyHandler."
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

        # assign handlers internally
        @on \read, (handle, respond) ~>
            #console.log "requested read!"
            err, value <~ driver.read handle
            #console.log "responding read value: ", err, value
            respond err, value

        @on \write, (handle, value, respond) ~>
            #console.log "requested write for #{handle.address}, value: ", value
            err <~ driver.write handle, value
            #console.log "write error status: ", err
            respond err

        # Initialize handle (do handle specific settings on the target)
        driver.initialize handle, broadcast-value

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

        if not driver.starting or not driver.started
            driver.start!
