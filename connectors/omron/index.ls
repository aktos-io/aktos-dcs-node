require! './hostlink/hostlink-serial-connector': {HostlinkSerialConnector}
require! './omron-protocol-actor': {OmronProtocolActor}
require! './hostlink/hostlink-protocol': {HostlinkProtocol}

module.exports = {
    HostlinkProtocol
    HostlinkSerialConnector
    OmronProtocolActor
}
