require! 'prelude-ls': {keys, map, join, take, at, drop}
require! '../../../': {EventEmitter, sleep, Signal, Logger}
require! './helpers': {
    get-data, check-hostlink-packet, addr, calc-fcs
    pad-two, pad-four
}


export class HostlinkProtocol extends EventEmitter
    (@transport, opts={}) ->
        super!
        @log = new Logger 'Hostlink'

        default-opts =
            unit-no: 0

        opts = default-opts <<< opts

        @log.log "A Hostlink protocol is created, opts: ", opts

        @unit-no = opts.unit-no

        @write-res = new Signal!
        @read-res = new Signal!

        @transport.on \data, (data) ~>
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


    _parse-addr: (address-part) ->
        if typeof! address-part is \Object
            area = keys address-part .0
            address = address-part[area]
        else
            area = address-part |> at 0
            address = address-part |> drop 1

        [area.to-upper-case!, address]

    write: (addr, data, callback) ->
        [area, address] = @_parse-addr addr
        data = [data] if typeof! data isnt \Array
        @_write @unit-no, area, address, data, callback

    read: (addr, size, callback) ->
        [area, address] = @_parse-addr addr
        @_read @unit-no, area, address, size, callback


    _read: (unit-no, address-type, address, size, callback) ->
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
        @transport.write _packet
        timeout, err, res <~ @read-res.wait 3000ms
        #@log.log "response of read packet: err: ", err, "res: ", res
        callback (timeout or err), res

    _write: (unit-no, address-type, address, data, callback) ->
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
        @transport.write _packet
        timeout, err, res <~ @write-res.wait 3000ms
        #@log.log "response of write packet: err: ", err, "res: ", res
        callback (timeout or err), res
