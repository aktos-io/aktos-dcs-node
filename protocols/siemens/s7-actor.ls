require! 'dcs': {Actor}
require! './nodeS7': nodes7
require! 'aea': {sleep, pack, unpack}

export class S7Actor extends Actor
    (target-opts, name) ->
        super name

        # S7 client
        @conn = new nodes7 {+silent}
        @target-opts = target-opts

        @on-kill (reason) ~>
            @log.log "TODO: close the connection"

        @on-receive (msg) ~>
            @log.log "got message: ", msg.payload

    action: ->
        @log.log "S7 Actor is created: ", @target-opts, @name
        @start!

    start: ->
        @connect ~> @start-read-poll!
        @add-to-read-poll 'MR4'
        @add-to-read-poll 'I0.0'

    connect: (callback) ->
        @conn.initiateConnection @target-opts, (err) ~>
            if err
                @log.log "we have an error: ", err
                @kill 'SIEMENS_CONN_ERR'
            else
                callback!

    start-read-poll: ->
        @log.log "started read-poll"
        prev-data = {}
        <~ :lo(op) ~>
            err, data <~ @conn.readAllItems
            @log.log "something went wrong while reading values" if err
            if pack(prev-data) isnt pack(data)
                prev-data := data 
                @send data, "#{@name}.read"
            <~ sleep 100ms
            lo(op)


    add-to-read-poll: (addr) ->
        @log.log "Adding address of #{addr} to the read poll."
        @conn.addItems addr


# --------------------------- TEST ------------------------------ #

class Monitor extends Actor
    ->
        super \Monitor
        @subscribe "mydevice.**"

        @on-receive (msg) ~>
            @log.log "Monitor got msg: ", msg.payload

    action: ->
        @log.log "#{@name} started..."

new S7Actor {port: 102, host: '192.168.0.1', rack: 0, slot: 1}, \mydevice
new Monitor!
