require! 'dcs': {Actor, TCPProxy}
require! 'aea': {sleep}
require! './database':{test-db}

class Simulator extends Actor
    ->
        super \simulator-1
        @subscribe 'simulator.**'

        @on \receive, (msg) ~>
            @log.log "got message: ", msg.payload

    action: ->
        do ~>
            <~ :lo(op) ~>
                msg = "message from #{@name}...."
                @log.log "sending #{msg}"
                @send msg, 'simulator.test1'
                <~ sleep 2000ms
                lo(op)

new TCPProxy do
    server-mode: on
    db: test-db 

#new Simulator!
