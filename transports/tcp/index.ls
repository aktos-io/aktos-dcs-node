require! 'node-net-reconnect': Reconnect
require! 'net'
require! 'colors': {yellow, green, red, blue, bg-green, bg-red}
require! '../../lib': {sleep, Logger, EventEmitter}
require! 'net-keepalive': NetKeepAlive


export class TcpHandlerTransport extends EventEmitter
    (@orig) ->
        super!
        @orig
            ..on \end, ~>
                @trigger \disconnect

            ..on \data, (data) ~>
                @trigger \data, data

    write: (data) ->
        @orig.write data


export class TcpTransport extends EventEmitter
    (opts={}) ->
        super!
        @opts =
            host: opts.host or "localhost"
            port: opts.port or 5523
            retry-always: yes

        @log = new Logger \TCP_Transport

        @socket = new net.Socket!
        Reconnect.apply @socket, @opts
        @connected = no

        @socket
            ..setKeepAlive yes, 1000ms
            ..setTimeout 1000ms

            ..on \connect, ~>
                NetKeepAlive.setKeepAliveInterval @socket, 1000ms
                NetKeepAlive.setKeepAliveProbes @socket, 1
                #@log.log "Connected. Try to unplug the connection"
                @connected = yes  # should be BEFORE "connect" trigger
                @trigger \connect

            ..on \close, ~>
                if @connected
                    @connected = no
                    #@log.log "Connection is closed."
                    @trigger \disconnect

            ..on \data, (data) ~>
                @trigger \data, data

        unless opts.manual-start
            # start automatically
            @start!

    start: ->
        #@log.log "Starting connection"
        @socket.connect @opts

    write: (data, callback) ->
        callback = (->) unless typeof! callback is \Function

        if @connected
            @socket.write data, ~>
                callback err=null
        else
            callback do
                message: 'not connected'

                /* disabling, because this will likely cause memory leak
                 * for long disconnections
                resolved: (callback) ~>
                    @once \connect, callback
                */

if require.main is module
    # open a server in another terminal:
    #
    #     nc -l -p 1234
    #
    logger = new Logger 'APP'
    transport = new TcpTransport {host: \localhost, port: 1234}
        ..on \connect, ->
            logger.log "transport connected"

        ..on \data, (frame) ~>
            logger.log "frame received:", frame.to-string!

        ..on \disconnect, ~>
            logger.log "transport disconnected "
    i = 0
    <~ :lo(op) ~>
        payload = "sending incremental data: #{i}"
        logger.log payload
        err <~ transport.write "#{payload}\n"
        if err
            logger.err "something went wrong while writing"
            #logger.err "waiting for resolution..."
            #<~ err.resolved
            #logger.log "error is resolved, continuing"
            <~ sleep 1000ms
            lo(op)
        else
            return op! if ++i > 10
            <~ sleep 2000ms
            lo(op)
    logger.log "End of tests."
