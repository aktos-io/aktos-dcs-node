require! 'serialport': SerialPort
require! '../../lib': {pack, sleep, clone, EventEmitter, Logger}
require! '../../src/signal': {Signal}

'''
Options: 

        opts =
            # SerialPort options: https://serialport.io/docs/en/api-stream#openoptions
            port: '/dev/ttyUSB0' or 'COM1'
            baudrate: 9600...
            dataBits: 8  
            stopBits: 1 
            parity: 'even' # or 'none' or 'odd'
            rtscts: true or false # see https://github.com/serialport/node-serialport/issues/203#issuecomment-22572847

            # This class' options
            split-at: null # null for raw reading. Possible options: '\n'

API: 

    .update(opts): Update parameters in runtime
'''

export class SerialPortTransport extends EventEmitter
    (@opts) ->
        default-opts =
            baudrate: 9600baud
            split-at: null  # string or function (useful for binary protocols)
            timeout: 50ms # `recv` buffer invalidation timeout 

        @opts = default-opts <<< @opts
        throw 'Port is required' unless @opts.port
        super!

        @log = new Logger "Serial #{@opts.port}"
        @reconnect-timeout = new Signal
        @_reconnecting = no
        @on \do-reconnect, ~>
            if @_reconnecting
                return @log.warn "Already trying to reconnect"
            @_reconnecting = yes

            @recv = ''
            @_last_receive = null

            #@log.log "opening port..."
            ser-opts = clone @opts 
            ser-opts.baudRate = ser-opts.baudrate
            delete ser-opts.split-at
            delete ser-opts.baudrate

            /* debug recv buffer 
            do 
                <~ :lo(op) ~> 
                    console.log "recv:", JSON.stringify @recv 
                    <~ sleep 1000ms 
                    lo(op)
            */

            @reconnect-timeout.wait 1000ms, (err, opening-err) ~>
                if err or opening-err
                    <~ sleep 1000ms
                    @ser = null
                    @trigger \do-reconnect

            unless @ser
                @ser = new SerialPort @opts.port, ser-opts, (err) ~>
                    #console.log "initializing ser:", err
                    @reconnect-timeout.go err
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
                    if @_last_receive? and @_last_receive + @opts.timeout < Date.now! 
                        #@log.info "Cleaning up receive buffer."
                        @recv = '' 
                    @_last_receive = Date.now! 
                    unless @opts.split-at
                        @trigger \data, data
                    else
                        @recv += data.to-string!
                        #@log.log "data is: ", JSON.stringify @recv
                        do 
                            re-examination-is-needed = no
                            index = @recv.index-of(@opts.split-at)
                            if index > -1
                                re-examination-is-needed = yes 
                                @trigger \data, @recv.substring(0, index)
                                @recv = @recv.substring(index + @opts.split-at.length)
                                # if recv? => @log.log "recv: ", JSON.stringify @recv
                        while re-examination-is-needed

                ..on \close, (e) ~>
                    #@log.log "something went wrong with the serial port...", e
                    @connected = no
                    <~ sleep 1000ms
                    @_reconnecting = no
                    @trigger \do-reconnect
            @_reconnecting = no
        @trigger \do-reconnect

    clear-buffer: -> 
        @recv = ''

    connected: ~
        ->
            @_connected
        (val) ->
            @_connected = val
            if not @_connected0 and @_connected
                @trigger \connect

            if @_connected0 and not @_connected 
                @trigger \disconnect

            @_connected0 = @_connected

    update: (o) -> 
        # change settings in runtime
        @opts <<< o 
        baudrate = o.baudrate
        if @ser
            delete o.split-at
            delete o.baudrate
            @ser.settings <<< o 
            if baudrate
                @ser.update {baudRate: that}
        return @opts 

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

    drain: (callback) -> 
        @ser.drain callback

    write-read: (data, timeout, callback) -> 
        # callback: (err, res)
        # timeout: milliseconds 
        if typeof! timeout is \Function 
            callback = timeout 
            timeout = null

        signal = new Signal 
        signal.wait timeout, callback
        if @connected
            /*
            received = []
            listener = @on \data, (data) ~> 
                console.log "received data:", data 
                received.push data 
                signal.heartbeat! 

            signal.on-timeout ~> 
                console.log "received is: ", received
                signal.go err=(received.length is 0), received 
                listener.cancel!
            */
            @once \data, (data) ~> 
                signal.go err=null, data

            @ser.write data
        else
            #@log.warn "not connected, not writing."
            signal.go err=
                message: 'not connected'


if require.main is module
    # do short circuit Rx and Tx pins
    logger = new Logger 'APP'
    port = new SerialPortTransport {
        baudrate: 9600baud
        port: '/dev/ttyUSB0'
        split-at: '\n'
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
