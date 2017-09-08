require! 'dcs': {Actor}
require! 'aea': {sleep}

require! './hostlink-tcp-server': {HostlinkTcpServer}

class TestWrite extends Actor
    ->
        super ...
        @subscribe 'public.**'

    action: ->
        val = 0
        <~ :lo(op) ~>
            @log.log "sending #{val}..."
            timeout, msg <~ @send-request {topic: "public.x", timeout: 500ms}, do
                write:
                    addr:
                        R: 92
                    data: [val]

            @log.log "response is: ", msg?.payload, "timeout: ", timeout
            err = timeout or msg?.err
            unless err
                val := (val + 1) %% 2
            <~ sleep 1000ms
            lo(op)

new HostlinkTcpServer!
new TestWrite!
