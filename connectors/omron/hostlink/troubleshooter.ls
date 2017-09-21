require! 'dcs': {Actor}
require! '../lib': {sleep}

require! './hostlink-tcp-server': {HostlinkTcpServer}

test-addr = R: 92

class TestWrite extends Actor
    ->
        super 'test writer'
        @subscribe 'public.**'

    action: ->
        val = 0
        <~ :lo(op) ~>
            @log.log "sending #{val}..."
            timeout, msg <~ @send-request {topic: "public.x", timeout: 500ms}, do
                write:
                    addr: test-addr
                    data: [val]

            @log.log "response is: ", msg?.payload, "timeout: ", timeout
            err = timeout or msg?.err
            unless err
                val := (val + 1) %% 2
            <~ sleep 2000ms
            lo(op)



class TestRead extends Actor
    ->
        super 'test reader'
        @subscribe 'public.**'

    action: ->
        <~ :lo(op) ~>
            @log.log "reading ", test-addr
            timeout, msg <~ @send-request {topic: "public.x", timeout: 500ms}, do
                read:
                    addr: test-addr
                    size: 1

            @log.log "response is: ", msg?.payload, "timeout: ", timeout
            <~ sleep 2000ms
            lo(op)


new HostlinkTcpServer!
new TestWrite!
new TestRead!
