require! '../../../transports/serial-port': {SerialPortTransport}
require! './hostlink-protocol': {HostlinkProtocol}
require! '../omron-protocol-actor': {OmronProtocolActor}
require! '../../..': {Actor, Logger, sleep, merge}

"""
usage:

    my-actor = new HostlinkSerialActor do
        transport:
            baudrate: 9600baud
            port: '/dev/ttyUSB0'
        subscribe: 'hey.**'
"""

export class HostlinkSerialConnector extends OmronProtocolActor
    (opts={}) ->
        default-opts =
            transport:
                split-at: '\r'
            hostlink:
                unit-no: 0

        opts = default-opts `merge` opts

        transport = new SerialPortTransport opts.transport
        protocol = new HostlinkProtocol transport

        super protocol, do
            name: 'HostlinkSerial'
            subscribe: opts.subscribe

        @log.log "HostlinkSerialActor is created with options: ", opts
