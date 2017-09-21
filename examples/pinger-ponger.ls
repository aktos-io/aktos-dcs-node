require! '../src/actor': {Actor}
require! '../lib': {sleep, pack, unpack}


class Pinger extends Actor
    ->
        super 'pinger'

    action: ->
        <~ :lo(op) ~>
            <~ sleep 1000ms
            @log.log "sending request from pinger"
            <~ @send-request 'ponger.request', 'this is a request from ponger'
            @log.log "received response from ponger"
            lo(op)


class Ponger extends Actor
    ->
        super 'ponger'
        @subscribe 'ponger.**'

        @on \data, (msg) ~>
            @log.log "got message: ", msg.payload
            <~ sleep 2000ms
            @send-response msg, 'this message is a response from ponger'


new Pinger!
new Ponger!
