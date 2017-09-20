require! 'dcs': {Actor, Signal}
require! 'prelude-ls': {keys, map, join, take, at, drop}
require! '../lib': {sleep, pack}
require! './helpers': {
    get-data, check-hostlink-packet, addr, calc-fcs
    pad-two, pad-four
}


export class HostlinkActor extends Actor
    (@socket, opts) ->
        super 'Hostlink Handler'
        @log.log "A Hostlink handler is created, opts: ", opts

        @unit-no = opts.unit-no or 0
        if opts.subscriptions
            @subscribe that

        @write-res = new Signal!
        @read-res = new Signal!

        @socket.on \data, (data) ~>
            packet = data.to-string!
            #@log.log "data received: ", packet
            try
                check-hostlink-packet packet
                data-part = get-data packet
                #@log.log "data part is: ", data-part
                if (packet |> take 5) is '@00WR'
                    if (packet |> take 7) is '@00WR00'
                        #@log.log "write response is ok"
                        @write-res.go null, {ok: yes}
                    else
                        #@log.log "write response seems erroneous"
                        @write-res {packet: packet}, null
                else
                    #@log.log "read response: ", data-part
                    @read-res.go null, data-part
            catch
                @write-res.go {err: e}, null
                @read-res.go {err: e}, null

        @socket.on \end, ~>
            @log.log "Hostlink connection is closed."
            @kill \disconnected

        parse-addr = (address-part) ->
            if typeof! address-part is \Object
                area = keys address-part .0
                address = address-part[area]
            else
                area = address-part |> at 0
                address = address-part |> drop 1

            [area.to-upper-case!, address]

        @on \data, (msg) ~>
            #@log.log "Hostlink actor got message from local interface: ", msg.payload
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
                #@log.log "processing cmd: ", cmd
                [area, address] = parse-addr cmd.addr
                err, res <~ @write @unit-no, area, address, cmd.data
                #@log.log "...written"
                @send-response msg, {err: err, res: res}

            else if \read of msg.payload
                cmd = msg.payload.read
                #@log.log "processing cmd: ", cmd
                [area, address] = parse-addr cmd.addr
                err, res <~ @read @unit-no, area, address, cmd.size
                #@log.log "...read response received"
                @send-response msg, {err: err, res: res}

            else
                err= {message: "got an unknown cmd"}
                @log.warn err.message, msg.payload
                @send-response msg, err


    read: (unit-no, address-type, address, size, callback) ->
        try
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
        catch
            @log.err e

        #@log.log "packet sent: #{_packet}"
        @read-res.clear!
        @socket.write _packet
        timeout, err, res <~ @read-res.wait 3000ms
        #@log.log "response of read packet: err: ", err, "res: ", res
        callback (timeout or err), res

    write: (unit-no, address-type, address, data, callback) ->
        try
            packet = "
                @
                #{unit-no |> pad-two}
                W
                #{address-type}
                #{address |> pad-four}
                #{data |> map pad-four |> join ''}
                "

            _packet = "
                #{packet}
                #{packet |> calc-fcs}
                *\r
                "
        catch
            @log.err e


        #@log.log "sending write packet: #{_packet}"
        @write-res.clear!
        @socket.write _packet
        timeout, err, res <~ @write-res.wait 3000ms
        #@log.log "response of write packet: err: ", err, "res: ", res
        callback (timeout or err), res
