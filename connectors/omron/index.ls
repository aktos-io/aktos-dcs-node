require! './hostlink/hostlink-serial-actor': {HostlinkSerialActor}
require! './omron-protocol-actor': {OmronProtocolActor}
require! './hostlink/hostlink-protocol': {HostlinkProtocol}

module.exports = {
    HostlinkProtocol
    HostlinkSerialActor
    OmronProtocolActor
}
