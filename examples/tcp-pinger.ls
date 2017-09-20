require! '..': {Actor, TCPProxyServer}
require! '../lib': {sleep}

class Pinger extends Actor
    ->
        super 'Pinger'

    action: ->
        <~ :lo(op) ~>
            <~ sleep 1000ms
            @log.log "sending request from pinger"
            <~ @send-request 'public.ponger', 'this is a request from ponger'
            @log.log "received response from ponger"
            lo(op)


new TCPProxyServer do
    port: 5678

new Pinger!
