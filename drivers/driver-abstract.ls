require! '../lib/event-emitter': {EventEmitter}
require! '../lib/sleep': {sleep}

export class DriverAbstract extends EventEmitter
    ->
        super!
        @rq = {}  # read queue

    write: (handle, value, respond) ->
        # respond(err)
        # if there is no error returned, broadcasting is the new value
        # is handled by io-proxy-handler
        ...

    _safe_read: (handle, respond) ->
        unless @rq[handle.route]
            #console.log "creating first queue item"
            @rq[handle.route] = [respond]
            <~ set-immediate
            err, res <~ @read handle
            for let r in @rq[handle.route]
                r err, res
            @rq[handle.route] = null
        else
            console.log "appending rest of read requests to the safe read queue"
            @rq[handle.route].push respond


    read: (handle, respond) ->
        # respond(err, res)
        ...

    watch-changes: (handle, emit) ->
        # if handle.watch is true, this method is called on initialization.
        # emit(err, res)
        if handle.watch
            console.log "...adding #{handle.route} to discrete watch list."
            <~ :lo(op) ~>
                <~ sleep handle.watch
                err, res <~ @_safe_read handle
                emit err, res
                lo(op)

    start: ->
        console.log "...driver is requested to start, but doing nothing."

    stop: ->
        console.log "...driver is requested to stop, but doing nothing."

    started: ->
        @trigger \connect
        @connected = yes

    stopped: ->
        @trigger \disconnect
        @connected = no

    parse-addr: (addr) ->
        /* return type:

            {
                addr: Array
                value: WRITE value or amount of words to READ
            }
        */
        if typeof! addr is \Array
            # like ["C0100", 5]
            return do
                type: \bool
                addr: addr
        if typeof! addr is \String
            [addr, bit] = addr.split '.'
            if bit?
                # like "C0100.05", bool
                return do
                    type: \bool
                    addr: [addr, parse-int bit]
            else
                # like "C0100", word
                return do
                    type: \word
                    addr: addr
        else
            console.log "Typeof addr: ", (typeof! addr), addr
