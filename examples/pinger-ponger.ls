require! 'aktos-dcs/src/actor': {Actor}
require! 'aea': {sleep, pack, unpack}

class Simulator extends Actor
    ->
        super ...

        @on-receive (msg) ~>
            @log.log "got message: ", msg.payload

    action: ->
        do ~>
            <~ :lo(op) ~>
                msg = "sending test message from #{@name}...."
                @log.log msg
                @send msg, '*' # send broadcast
                <~ sleep 2000ms
                lo(op)

new Simulator \...pinger
new Simulator \ponger...
