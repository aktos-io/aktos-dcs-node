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
            @send "public.x", do
                write:
                    addr:
                        R: 92
                    data: [val]
            val := (val + 1) %% 2
            <~ sleep 2000ms
            lo(op)

new HostlinkTcpServer!
new TestWrite!
