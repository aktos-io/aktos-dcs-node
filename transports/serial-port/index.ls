require! 'serialport': SerialPort
require! '../../lib': {pack, sleep, EventEmitter, Logger}

/* Example

port = new SerialPortTransport do
    port: '/dev/ttyUSB0'
    baudrate: 19200
    dataBits: 7         # 8, 7
    parity: 'even'      # 'none', 'even', 'odd'
    stopBits: 1
    split-at: null      # null for raw reading

*/

# Documentation for SerialPort: https://serialport.io/docs/en/api-stream#openoptions
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

        @log = new Logger "Serial #{opts.port}"
        @_reconnecting = no
        @on \do-reconnect, ~>
            if @_reconnecting
                return @log.warn "Already trying to reconnect"
            @_reconnecting = yes

            recv = ''
            #@log.log "opening port..."
            ser-opts =
                baud-rate: opts.baudrate
                stop-bits: opts.stop-bits
                dataBits: opts.dataBits
                parity: opts.parity

            unless @ser
                @ser = new SerialPort opts.port, ser-opts, (err) ~>
                    unless err
                        @connected = yes

                #console.log "serial port is:", @ser

            @ser
                ..on \error, (e) ~>
                    @log.warn "Error while opening port: ", pack e
                    @ser = null
                    <~ sleep 1000ms
                    @_reconnecting = no
                    @trigger \do-reconnect

                ..on \open, ~>
                    @connected = yes

                ..on \data, (data) ~>
                    unless opts.split-at
                        @trigger \data, data
                    else
                        recv += data.to-string!
                        #@log.log "data is: ", recv
                        if recv.index-of(opts.split-at) > -1
                            @trigger \data, recv
                            recv := ''

                ..on \close, (e) ~>
                    #@log.log "something went wrong with the serial port...", e
                    @connected = no
                    <~ sleep 1000ms
                    @_reconnecting = no
                    @trigger \do-reconnect
            @_reconnecting = no
        @trigger \do-reconnect

    connected: ~
        ->
            @_connected
        (val) ->
            @_connected = val
            if @_connected
                @trigger \connect
            else
                @trigger \disconnect

    write: (data, callback) ->
        if @connected
            #@log.log "writing data..."
            @ser.write data, ~>
                #@log.log "written data"
                callback? err=no
        else
            #@log.warn "not connected, not writing."
            callback? do
                message: 'not connected'

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

    <~ port.once \connect
    <~ :lo(op) ~>
        logger.log "sending \"something * 5\"..."
        err <~ port.write ('something' * 5) + '\n'
        if err
            logger.err "something went wrong while writing: ", err
            <~ port.once \connect
            logger.log "error is resolved, continuing"
            lo(op)
        else
            <~ sleep 2000ms
            lo(op)
