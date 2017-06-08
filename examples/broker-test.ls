require! 'aktos-dcs/src/broker': {Broker}
require! 'aktos-dcs/src/actor': {Actor}
require! 'aea': {sleep}
argv = require 'yargs' .argv

instance-name = argv.instance

class Simulator extends Actor
    ->
        super ...

        @on-receive (msg) ~>
            @log.log "got message: ", msg.payload

    action: ->
        do ~>
            <~ :lo(op) ~>
                msg = "message from #{@name}...."
                @log.log "sending #{msg}"
                @send msg, '**' # send broadcast
                <~ sleep 2000ms
                lo(op)

new Broker!
new Simulator "simulator-#{instance-name}"
