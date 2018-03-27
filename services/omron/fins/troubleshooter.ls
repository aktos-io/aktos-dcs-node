require! 'dcs': {Actor, sleep, pack}
require! './omron-fins-client': {OmronFinsClient}

class DataSourceSimulator extends Actor
    (@opts)->
        super @opts.name
        @subscribe "#{@opts.name}.**"
        @on \data, (msg) ~>
            @log.log "simulator got message: #{pack msg.payload}"

    action: ->
        @log.log "Simulator started..."
        x = no
        jitter = Math.random! * 3
        console.log "jitter is: ", jitter
        <~ sleep jitter
        do ~>
            <~ :lo(op) ~>
                @log.log "sending: " , x
                @send "#{@opts.name}.write", {write: addr: "C100.#{@opts.bit}", val: x}
                x := not x
                <~ sleep 1000ms
                lo(op)

new DataSourceSimulator {name: \io.my1, bit: 1}
new OmronFinsClient {name: \io.my1}
