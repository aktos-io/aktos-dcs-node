require! 'net'
require! './actor': {Actor}
require! 'prelude-ls': {
    chars, take, split-at, drop
}
require! 'aea': {sleep}


A_TYPES =
    relay: 'R'
    data: 'D'
    holding: 'H'

calc-fcs = (packet) ->
    hex = (n) -> n.to-string 16
    fcs = 0
    for c in chars packet
        fcs = fcs .^. c.charCodeAt(0)
    "00#{hex fcs}".slice -2

do test-calc-fcs = ->
    examples =
        * packet: "@00RD00000001", expected: "57"
        * packet: "@00RD00000002", expected: "54"

    for index of examples
        example = examples[index]
        result = calc-fcs(example.packet)
        if result isnt example.expected
            throw "test-calc-fcs failed at: \##{index} (expected: #{example.expected}, result: #{result})"


check-hostlink-packet = (packet) ->
    structure = // # check if input is a valid Hostlink query
        # returns true/false
        # --------------------------------------------
        | /^@          # start header
        | [0-3][0-9]   # unit no, must be 00-31
        | [RW]         # Command: [R]ead or [W]rite
        | [RDH]        # Memory type:
                       #   R: Common area
                       #   D: Data memory
                       #   H: Holding area
        | [0-9]{4}     # Address, 0000-9999 (BCD)
        | [0-9A-F]{4,} # Data or Size, 4 characters at least
        | [0-9A-F]{2}  # Frame Check Sequence
        | \*\r$/       # End header
        // .test packet

    if structure isnt true
        throw "Structure is not correct"

    packet = take (packet.length - 2), packet

    test-fcs = (packet) ->
        [packet, fcs] = split-at (packet.length - 2), packet
        throw 'FCS is not correct' if fcs isnt calc-fcs packet

    test-fcs packet

get-data = (packet) ->
    packet = take (packet.length - 4), packet
    data-part = drop 7, packet
    slice-every = (n, str) ->
        result = []
        while str.length > 0
            [_first, str] = split-at n, str
            result.push _first
        result
    slice-every 4, data-part

class HostlinkActor extends Actor
    (socket) ->
        super!
        @socket = socket
        @log.log "Device connected."

        @socket.on \data, (data) ~>
            packet = data.to-string!
            @log.log "packet received: ", packet
            try
                check-hostlink-packet packet
                data-part = get-data packet
                @read-handler data-part
            catch e
                @log.err "Problem: ", e

        <~ :lo(op) ~>
            data <~ @read 0, A_TYPES.data, 1254, 15
            @log.log "read function returned: ", data
            <~ sleep 1000ms
            lo(op)


    read: (unit-no=0, address-type, address, size, handler) ->
        unit-no = "00#{unit-no}".slice -2
        address = "0000#{address}".slice -4
        size = "0000#{size}".slice -4

        packet = "@#{unit-no}R#{address-type}#{address}#{size}"
        _packet = "#{packet}#{calc-fcs packet}*\r"
        @log.log "packet sent: #{_packet}"
        @socket.write _packet
        @read-handler = handler

    write: (addres-type, address, data) ->
        @socket.write "@00RD0000000157*\r"
        #socket.pipe socket


class Broker extends Actor
    ->
        super ...
        @server = null
        @create-server!

    create-server: ->
        @server = net.create-server (socket) ->
            new HostlinkActor socket

        @server.listen 5522, '0.0.0.0', ~>
            @log.log "Broker started listening..."



new Broker!
