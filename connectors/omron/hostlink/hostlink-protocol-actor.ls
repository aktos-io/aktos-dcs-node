require! '../../..': {Actor}


export class HostlinkProtocolActor extends Actor
    (@protocol, name) ->
        super (name or 'ProtocolActor')

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
                err, res <~ @protocol.write cmd.addr, cmd.data
                @send-response msg, {err: err, res: res}

            else if \read of msg.payload
                cmd = msg.payload.read
                err, res <~ @protocol.read cmd.addr, cmd.size
                @send-response msg, {err: err, res: res}

            else
                err= {message: "got an unknown cmd"}
                @log.warn err.message, msg.payload
                @send-response msg, err
