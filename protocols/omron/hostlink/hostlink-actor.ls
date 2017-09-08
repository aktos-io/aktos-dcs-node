require! 'dcs': {Actor, FpsExec}
require! 'prelude-ls': {map, join}
require! 'aea': {sleep}
require! './helpers': {get-data, check-hostlink-packet, addr, calc-fcs}

export class HostlinkActor extends Actor
    (@socket) ->
        super!
        @subscribe "public.**"
        @fps = new FpsExec 2fps

        @socket.on \connect, ~>
            @log.log "hostlink actor connected."

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

        @on \data, (msg) ~>
            x = if msg.payload.val
                1
            else
                0
            @log.log "Hostlink actor got message from local interface: ", x
            <~ @write 0, addr.relay, 92, [x]
            #@log.log "...written"

    action: ->
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
                <~ @write 0, addr.relay, 92, [0]
                <~ sleep 1000ms
                <~ @write 0, addr.relay, 92, [1]
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

    write: (unit-no=0, address-type, address, data, handler) ~>
        unit-no = "00#{unit-no}".slice -2
        address = "0000#{address}".slice -4

        data = map ((d) -> "0000#{d}".slice -4), data
        data = join '', data

        packet = "@#{unit-no}W#{address-type}#{address}#{data}"
        _packet = "#{packet}#{calc-fcs packet}*\r"
        @log.log "sending write packet: #{_packet}"
        #@fps.exec-context @socket, @socket.write, _packet
        @socket.write _packet
        #@socket.write _packet
        @read-handler = handler
