require! 'aktos-dcs/protocol-actors/hostlink': {HostlinkServerActor}
require! 'aktos-dcs/src/actor': {Actor}
require! 'aktos-dcs/src/broker': {Broker}
require! 'aea': {sleep}

new HostlinkServerActor!

class Simulator extends Actor
    ->
        super ...
        @subscribe "IoMessage.my-test-pin1"

    action: ->
        @log.log "Simulator started..."
        x = 0
        do ~>
            <~ :lo(op) ~>
                @log.log "sending: #{x}"
                @send x, "IoMessage.my-test-pin1"
                x += 2
                <~ sleep 1000ms
                lo(op)

class Monitor extends Actor
    ->
        super \Monitor
        @subscribe "IoMessage.my-test-pin3"

        @on-receive (msg) ~>
            @log.log "Monitor got msg: ", msg.payload

    action: ->
        @log.log "#{@name} started..."

#new Simulator "mahmut"
new Monitor!
new Broker!
