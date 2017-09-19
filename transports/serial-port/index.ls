require! 'serialport': SerialPort
require! 'aea': {sleep, EventEmitter}
require! 'dcs': {Actor}
require! 'colors': {bg-green, bg-red}


class SerialPortConnector extends EventEmitter
    (opts) ->
        """
        opts:
            name: actor name
            port: /dev/ttyUSB0 or COM1
            baudrate: 9600...
        """
        default-opts =
            name: \serial-port
            baudrate: 9600baud
            port: '/dev/ttyUSB0'
            split-at: '\n'  # string or function (useful for binary protocols)

        opts = default-opts <<< opts
        super opts.name

        port = new SerialPort opts.port, do
            baudrate: opts.baudrate

        recv = ''
        port
            ..on \open, ->
                console.log "Port open"

            ..on \data, (data) ~>
                recv += data.to-string!
                if recv.index-of('\n') > -1
                    console.log "data is: ", recv
                    @send recv, 'serialport.one.rx'
                    recv := ''

        @on \data, (msg) ~>
            @log.log "writing to serial port: #{msg.payload}"
            port.write msg.payload
            @send-response msg, {ok}

        i = 0
        do # poller
            <~ :lo(op) ~>
                @log.log "polling..."
                port.write "poll-cmd #{i++}\n"
                <~ sleep 2000ms
                lo(op)
