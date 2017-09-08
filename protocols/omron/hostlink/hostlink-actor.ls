require! 'dcs': {Actor, FpsExec, Signal}
require! 'prelude-ls': {keys, map, join, take}
require! 'aea': {sleep, pack}
require! './helpers': {get-data, check-hostlink-packet, addr, calc-fcs}

pad-two = (x) -> "00#{x}".slice -2
pad-four = (x) -> "0000#{x}".slice -4

export class HostlinkActor extends Actor
    (@socket) ->
        super!
        @subscribe "public.**"
        @fps = new FpsExec 2fps
        @write-res = new Signal!
        @read-res = new Signal!

        @socket.on \connect, ~>
            @log.log "hostlink actor connected."

        @socket.on \data, (data) ~>
            packet = data.to-string!
            @log.log "data received: ", packet
            try
                check-hostlink-packet packet
                data-part = get-data packet
                @log.log "data part is: ", data-part
                if (packet |> take 5) is '@00WR'
                    if (packet |> take 7) is '@00WR00'
                        @log.log "write response is ok"
                        @write-res.go null, {ok: yes}
                    else
                        @log.log "write response seems erroneous"
                        @write-res {packet: packet}, null
                else
                    @log.log "read response: ", data-part
                    @read-res.go null, data-part
            catch
                @write-res.go {err: e}, null
                @read-res.go {err: e}, null

        @socket.on \end, ~>
            @log.log "Hostlink connection is closed."
            @kill \disconnected

        @on \data, (msg) ~>
            @log.log "Hostlink actor got message from local interface: ", msg.payload
            /*
            message structure:

                write:
                    addr:
                        R: 1234
                    data: [111, 222, 333, ...]

                read:
                    addr:
                        D: 1234
                    size: 11
            */
            if \write of msg.payload
                cmd = msg.payload.write
                area = keys cmd.addr .0
                address = cmd.addr[area]
                <~ @write 0, area, address, cmd.data
                @log.log "...written"

    action: ->
        @log.log "A Hostlink device is connected."

    disabled-action: ->
        @log.log "starting write loop"
        <~ :lo(op) ~>
            <~ @write 0, addr.relay, 92, [0]
            <~ sleep 1000ms
            <~ @write 0, addr.relay, 92, [1]
            <~ sleep 1000ms
            lo(op)

    read: (unit-no=0, address-type, address, size, handler) ->
        packet = "
            @
            #{unit-no |> pad-two}
            R
            #{address-type}
            #{address |> pad-four}
            #{size |> pad-four}
            "

        _packet = "
            #{packet}
            #{packet |> calc-fcs}
            *\r
            "

        #@log.log "packet sent: #{_packet}"
        @read-res.clear!
        @socket.write _packet
        timeout, err, res <~ @read-res.wait 3000ms
        @log.log "response of read packet: err: ", err, "res: ", res
        callback (timeout or err), res

    write: (unit-no=0, address-type, address, data, callback) ->
        try
            @log.warn "address type: ", address-type
            @log.warn "address: ", address
            @log.warn "data", data
            packet = "
                @
                #{unit-no |> pad-two}
                W
                #{address-type}
                #{address |> pad-four}
                #{data |> map pad-four |> join ''}
                "
        catch
            @log.err "exception: ", e

        _packet = "
            #{packet}
            #{packet |> calc-fcs}
            *\r
            "

        #@log.log "sending write packet: #{_packet}"
        @write-res.clear!
        @socket.write _packet
        timeout, err, res <~ @write-res.wait 3000ms
        @log.log "response of write packet: err: ", err, "res: ", res
        callback (timeout or err), res
