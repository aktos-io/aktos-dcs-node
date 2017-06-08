require! 'net'
require! 'aktos-dcs/src/actor': {Actor}
require! 'aktos-dcs/src/filters': {FpsExec}
require! 'prelude-ls': {
    chars, take, split-at, drop
    map, join
}
require! 'aea': {sleep}
require! 'aea/signal': {watchdog, watchdog-kick}


A_TYPES =
    relay: 'R'
    data: 'D'
    holding: 'H'

calc-fcs = (packet) ->
    hex = (n) -> n.to-string 16 .to-upper-case!
    fcs = 0
    for c in chars packet
        fcs = fcs .^. c.charCodeAt(0)
    "00#{hex fcs}".slice -2

do test-calc-fcs = ->
    examples =
        * packet: "@00RD00000001", expected: "57"
        * packet: "@00RD00000002", expected: "54"
        * packet: "@00RD000008", expected: "5E"

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

        @subscribe "IoMessage.my-test-pin3"
        @fps = new FpsExec 2fps

        @socket.on \data, (data) ~>
            packet = data.to-string!
            #@log.log "packet received: ", packet
            try
                check-hostlink-packet packet
                data-part = get-data packet
                if typeof! @read-handler is \Function
                    @read-handler data-part
            catch e
                @log.err "Problem: ", e


        @on-receive (msg) ~>
            x = parse-int msg.payload
            #@log.log "Hostlink actor got message from local interface: ", x
            <~ @write 0, A_TYPES.data, 1254, [x]
            #@log.log "...written"

    action: ->
        @log.log "A Hostlink device is connected."

    action-disabled: ->
        @log.log "A Hostlink device is connected."
        /*
            TODO:

            needed timeout
            error response on read packages
            handle response on write packats

        */
        do ~>
            @log.log "starting write loop"
            <~ :lo(op) ~>
                @log.log "reading package...."
                data <~ @read 0, A_TYPES.data, 1254, 1
                @log.log "package has been read!"
                try
                    my = parse-int data.0
                    throw 'not a number?' if my % 1 isnt 0
                catch
                    @log.log "is it a number: ", data.0
                    my = 5
                <~ sleep 1000ms
                <~ @write 0, A_TYPES.data, 1254, [++my]
                <~ sleep 1000ms
                lo(op)

    read: (unit-no=0, address-type, address, size, handler) ->
        unit-no = "00#{unit-no}".slice -2
        address = "0000#{address}".slice -4
        size = "0000#{size}".slice -4

        packet = "@#{unit-no}R#{address-type}#{address}#{size}"
        _packet = "#{packet}#{calc-fcs packet}*\r"
        #@log.log "packet sent: #{_packet}"
        @socket.write _packet
        @read-handler = handler

    write: (unit-no=0, address-type, address, data, handler) ->
        unit-no = "00#{unit-no}".slice -2
        address = "0000#{address}".slice -4

        data = map ((d) -> "0000#{d}".slice -4), data
        data = join '', data

        packet = "@#{unit-no}W#{address-type}#{address}#{data}"
        _packet = "#{packet}#{calc-fcs packet}*\r"
        @log.log "sending write packet: #{_packet}"
        @fps.exec2 @socket, @socket.write, _packet
        #@socket.write _packet
        @read-handler = handler


export class HostlinkServerActor extends Actor
    ->
        super ...
        @server = null
        @create-server!

    create-server: ->
        @server = net.create-server (socket) ->
            new HostlinkActor socket

        @server.listen 5522, '0.0.0.0', ~>
            @log.log "Broker started listening..."
