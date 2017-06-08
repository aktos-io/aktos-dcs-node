require! 'aktos-dcs/protocol-actors/hostlink': {HostlinkServerActor}
require! 'aktos-dcs/src/actor': {Actor}
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

new Simulator "mahmut"
