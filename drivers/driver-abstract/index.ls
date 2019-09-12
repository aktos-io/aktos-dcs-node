require! '../../lib/event-emitter': {EventEmitter}
require! '../../lib/logger': {Logger}

export class DriverAbstract extends EventEmitter
    ->
        super!
        @_queue = []  # sequential operations queue
        @io = {}  # io lookup table, format: {"name": object}
        @logger = new Logger implemented-by=@@@name

    init-handle: (handle, broadcast) ->
        # broadcast(err, value)
        # 
        # Register pointers for later use: 
        #@io[handle.id] = handle 
        ...

    write: (handle, value, respond) ->
        # respond(err)
        # if there is no error returned, broadcasting the new value is handled
        # by io-proxy-handler
        ...

    _exec_sequential: (func, ...args, callback) ->
        # execute `func` with `...args`
        @_queue.push arguments
        ...

    read: (handle, respond) ->
        # respond(err, res)
        ...

    start: ->
        @starting = yes 
        @logger.log "Driver immediately started."
        @connected = yes 

    connected: ~
        ->
            @_connected
        (val) ->
            if val is yes 
                @_connected = yes
                @started = yes
                @trigger \connect
            else
                @_connected = no
                @started = no
                @starting = no
                @trigger \disconnect
