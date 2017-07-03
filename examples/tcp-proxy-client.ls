require! 'dcs': {Actor, TCPProxy}
require! 'aea': {sleep}
require! 'colors': {bg-green, bg-red}

class Simulator extends Actor
    ->
        super \client-simulator
        @subscribe 'authorization.**'

        @on \receive, (msg) ~>
            @log.log "got message: ", msg.payload

    action: ->
        do ~>
            <~ :lo(op) ~>
                msg = "message from #{@name}...."
                @log.log "sending #{msg}"
                @send msg, 'authorization.test1'
                <~ sleep 2000ms
                lo(op)


new TCPProxy do
    server-mode: off

new Simulator!
