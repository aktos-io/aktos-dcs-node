require! '../lib/event-emitter': {EventEmitter}

export class DriverAbstract extends EventEmitter
    write: (handle, value, respond) ->
        # respond(err)
        # if there is no error returned, broadcasting is the new value
        # is handled by io-proxy-handler
        ...

    read: (handle, respond) ->
        # respond(err, res)
        ...

    watch-changes: (handle, emit) ->
        # if handle.watch is true, this method is called on initialization.
        # emit(err, res)
        ...

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
