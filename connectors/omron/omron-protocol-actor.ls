"""
message structure:

    write:
        addr:
            R: 1234
        data: [111, 222, 333, ...]

    read:
        addr:
            D: 1234
        size: 11

"""
require! '../..': {Actor}


export class OmronProtocolActor extends Actor
    (@protocol, opts={}) ->
        super (opts.name or 'ProtocolActor')

        @subscribe that if opts.subscribe

        @on \data, (msg) ~>
            @log.log "omron protocol actor received from dcs network: ", msg.payload
            if \write of msg.payload
                cmd = msg.payload.write
                err, res <~ @protocol.write cmd.addr, cmd.data
                @send-response msg, {err: err, res: res}

            else if \read of msg.payload
                cmd = msg.payload.read
                err, res <~ @protocol.read cmd.addr, cmd.size
                @send-response msg, {err: err, res: res}

            else if \error of msg.payload
                @log.log "this is a error message from outside."
            else
                err= {error: message: "got an unknown cmd"}
                @log.warn err.message, msg.payload
                @send-response msg, err
