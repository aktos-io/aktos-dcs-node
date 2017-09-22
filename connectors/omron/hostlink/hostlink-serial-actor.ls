require! '../../../transports/serial-port': {SerialPortTransport}
require! './hostlink-protocol': {HostlinkProtocol}
require! './hostlink-protocol-actor': {HostlinkProtocolActor}
require! '../../..': {Actor, Logger, sleep, merge}


export class HostlinkSerialActor extends HostlinkProtocolActor
    (opts={}) ->
        default-opts =
            transport:
                #baudrate: 9600baud
                #port: '/dev/ttyUSB0'
                split-at: '\r'

            hostlink:
                unit-no: 0

        opts = default-opts `merge` opts

        transport = new SerialPortTransport opts.transport
        hostlink = new HostlinkProtocol transport

        super hostlink, 'HostlinkSerial'
        @subscribe that if opts.subscribe

        @log.log "HostlinkSerialActor is created with options: ", opts

        /* for debugging purposes
        logger = @log
        transport
            ..on \connect, ->
                logger.log "serial port is connected"

            ..on \data, (frame) ~>
                logger.log "frame received:", JSON.stringify frame

            ..on \disconnect, ~>
                logger.log "disconnected "


        <~ transport.once \connect
        <~ :lo(op) ~>
            err, res <~ hostlink.write 'R92', 0
            logger.log "hostlink write, err: ", err, "res: ", res
            <~ sleep 1000ms
            <~ hostlink.write 'R92', [1]
            logger.log "hostlink write, err: ", err, "res: ", res
            <~ sleep 2000ms
            lo(op)
        */


if require.main is module
    new HostlinkSerialActor do
        transport:
            baudrate: 9600baud
            port: '/dev/ttyUSB0'
        subscribe: "hostlink.**"

    class Test extends Actor
        action: ->
            @log.log "Hello from monitor!"
            <~ :lo(op) ~>
                err, res <~ @send-request 'hostlink.hey', do
                    write:
                        addr: R: 92
                        data: 0

                @log.log "err: ", err, "res: ", res
                <~ sleep 1000ms

                err, res <~ @send-request 'hostlink.hey', do
                    write:
                        addr: R: 92
                        data: 1
                @log.log "err: ", err, "res: ", res
                <~ sleep 1000ms
                lo(op)

    new Test!
