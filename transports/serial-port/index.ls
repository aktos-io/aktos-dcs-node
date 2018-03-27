require! 'serialport': SerialPort
require! '../..': {Actor, sleep, EventEmitter, Logger}
require! '../../lib': {pack}


export class SerialPortTransport extends EventEmitter
    (opts) ->
        """
        opts =
            port: '/dev/ttyUSB0' or 'COM1'
            baudrate: 9600...
        """
        default-opts =
            baudrate: 9600baud
            split-at: '\n'  # string or function (useful for binary protocols)

        opts = default-opts <<< opts
        throw 'Port is required' unless opts.port
        super!

        do # prevent process from terminating
            <~ :lo(op) ~>
                <~ sleep 99999999
                lo(op)

        @log = new Logger "Serial #{opts.port}"

        @_connected = no
        @_reconnecting = no
        @on \do-reconnect, ~>
            return @log.warn "Already trying to reconnect" if @_reconnecting
            @_reconnecting = yes

            recv = ''
            <~ :lo(op) ~>
                #@log.log "opening port..."
                @ser = new SerialPort opts.port, {baudrate: opts.baudrate}

                @ser
                    ..on \error, (e) ~>
                        #@log.warn "Error while opening port: ", pack e
                        <~ sleep 1000ms
                        @ser = undefined
                        @_reconnecting = no
                        @trigger \do-reconnect

                    ..on \open, ~>
                        @trigger \connect

                    ..on \data, (data) ~>
                        recv += data.to-string!
                        #@log.log "data is: ", JSON.stringify recv
                        if recv.index-of(opts.split-at) > -1
                            @trigger \data, recv
                            recv := ''

                    ..on \close, (e) ~>
                        #@log.log "something went wrong with the serial port...", e
                        @trigger \disconnect
                        <~ sleep 1000ms
                        @_reconnecting = no
                        @trigger \do-reconnect

            @_reconnecting = no

        @on do
            connect: ~>
                @_connected = yes

            disconnect: ~>
                @_connected = no

        @trigger \do-reconnect

    write: (data, callback) ->
        callback = (->) unless typeof! callback is \Function

        if @_connected
            #@log.log "writing data..."
            @ser.write data, ~>
                #@log.log "written data"
                callback err=no
        else
            #@log.warn "not connected, not writing."
            callback do
                message: 'not connected'
                resolved: (callback) ~>
                    @once \connect, callback

if require.main is module
    # do short circuit Rx and Tx pins
    logger = new Logger 'APP'
    port = new SerialPortTransport {
        baudrate: 9600baud
        port: '/dev/ttyUSB0'
        }
        ..on \connect, ->
            logger.log "app says serial port is connected"

        ..on \data, (frame) ~>
            logger.log "frame received:", frame

        ..on \disconnect, ~>
            logger.log "app says disconnected "

    <~ :lo(op) ~>
        logger.log "sending something..."
        err <~ port.write ('something' * 40) + '\n'
        if err
            logger.err "something went wrong while writing, waiting for resolution..."
            <~ err.resolved
            logger.log "error is resolved, continuing"
            lo(op)
        else
            <~ sleep 2000ms
            lo(op)
