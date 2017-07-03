require! 'dcs': {Actor, TCPProxy}
require! 'aea': {sleep}
require! 'colors': {bg-red}

class Simulator extends Actor
    ->
        super \simulator-2
        @subscribe 'authorization.**'

        @on \receive, (msg) ~>
            @log.log bg-red "got message: ", msg.payload

    maction: ->
        do ~>
            <~ :lo(op) ~>
                msg = "message from #{@name}...."
                @log.log "sending #{msg}"
                @send msg, 'authorization.test1'
                <~ sleep 2000ms
                lo(op)


class Simulator2 extends Actor
    ->
        super \simulator-3
        @subscribe 'authorization.**'

    action: ->
        do ~>
            <~ :lo(op) ~>
                msg = "message from #{@name}...."
                @log.log "sending #{msg}"
                @send msg, 'authorization.test1'
                <~ sleep 2000ms
                lo(op)

/*
new TCPProxy do
    server-mode: off
*/

new Simulator!
new Simulator2!
