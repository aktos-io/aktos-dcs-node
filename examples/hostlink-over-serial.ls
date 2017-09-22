require! '../connectors/omron': {HostlinkSerialActor}
require! '..': {Actor, sleep}

new HostlinkSerialActor do
    transport:
        baudrate: 9600baud
        port: '/dev/ttyUSB0'
    subscribe: "hostlink.**"

class Test extends Actor
    action: ->
        @log.log "Hello from test!"
        <~ :lo(op) ~>
            err, res <~ @send-request 'hostlink.hey', do
                write:
                    addr: R: 92
                    data: 0

            if err or res.payload.err
                @log.err "err: ", that, "res: ", res
            else
                @log.log "err: ", that, "res: ", res

            <~ sleep 1000ms

            err, res <~ @send-request 'hostlink.hey', do
                write:
                    addr: R: 92
                    data: 1
            @log.log "err: ", (err or res.payload.err), "res: ", res
            <~ sleep 1000ms
            lo(op)

new Test!
