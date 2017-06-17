require! 'dcs/protocols': {S7Actor}
require! 'dcs': {Actor, Broker}
require! 'aea': {sleep}

class Simulator extends Actor
    (name) ->
        super name
        @subscribe "mydevice.**"

        @on-receive (msg) ~>
            @log.log "got msg: ", msg.payload, "topic: #{msg.topic}"

    action: ->
        @log.log "#{@name} started..."

        # send periodic test messages
        my-toggle = off
        <~ :lo(op) ~>
            @send my-toggle, 'mydevice.testOutput'
            my-toggle := not my-toggle
            <~ sleep 1000ms
            lo(op)


console.log "Creating actors..."
new S7Actor do
    target: {port: 102, host: '192.168.0.1', rack: 0, slot: 1}
    name: \mydevice
    memory-map:
        test-input: 'I0.0'
        test-output: 'Q0.1'

new Simulator 'siem.test.simulator'
new Broker!
