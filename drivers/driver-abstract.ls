require! '../lib/event-emitter': {EventEmitter}
require! '../src/signal': {Signal}
require! '../lib/sleep': {sleep}
require! 'prelude-ls': {empty}

/* Types of drivers:

According to concurrency:

    1. Concurrent read/write

        A device might be able to handle its io concurrently, such as:
        * Raspberry GPIO
        * A database/webservice
        * More than one device in the backend

    2. Sequential read/write

        A device might not let concurrent read/writes (most of the devices) that
        can only handle one telegram at a time, such as
        * Most of the PLC's (especially which uses RS485 or like)

TODO: This distinction should be declared on `start` time.

*/

export class DriverAbstract extends EventEmitter
    ->
        super!
        @rq = {}  # read queue
        @io = {}  # io lookup table, format: {"name": object}

    init-handle: (handle, emit) ->
        console.log "TODO: Handle initialized:", handle
        # emit(err, res)
        if handle.watch
            console.log "...adding #{handle.route} to discrete watch list."
            <~ :lo(op) ~>
                <~ sleep handle.watch
                err, res <~ @_safe_read handle
                emit err, res
                lo(op)

    write: (handle, value, respond) ->
        # respond(err)
        # if there is no error returned, broadcasting the new value is handled
        # by io-proxy-handler
        ...

    _safe_read: (handle, respond) ->
        if empty (@rq[handle.route] or [])
            #console.log "creating first queue item: ", handle.route
            @rq[handle.route] = [respond]
            s = new Signal
            @read handle, (err, res) ~>
                s.go err, res
            err, res <~ s.wait 2000ms
            try
                for let @rq[handle.route]
                    .. err, res
            catch
                console.log "error while safe reading"

            #console.log "removing #{handle.route} handler from @rq"
            delete @rq[handle.route]
        else
            console.log "appending rest of read requests to the safe read queue"
            @rq[handle.route].push respond


    read: (handle, respond) ->
        # respond(err, res)
        ...

    start: ->

    stop: ->

    connected: ~
        ->
            @_connected
        (val) ->
            if val
                @_connected = yes
                @started = yes
                @trigger \connect
            else
                @_connected = no
                @started = no
                @starting = no
                @trigger \disconnect

    parse-addr: (addr) ->
        # A static method for parsing addresses.
        # TODO: Move to a separate library.
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
