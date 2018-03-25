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
        do ~>
            <~ :lo(op) ~>
                @log.log "sending: " , x
                @send "#{@opts.name}.write", {write: {bit: 0, val: x}}
                x := not x
                <~ sleep 2000ms
                lo(op)


new DataSourceSimulator {name: \io.my1}
new OmronFinsClient {name: \io.my1}
