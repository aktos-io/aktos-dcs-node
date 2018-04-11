require! 'nodes7': NodeS7
require! 'dcs': {EventEmitter, Logger, sleep, pack}
require! 'dcs/lib/memory-map': {bit-write, bit-test}
require! '../../driver-abstract': {DriverAbstract}
require! 'prelude-ls': {abs}
require! 'colors': {bg-green}


export class SiemensS7Driver extends DriverAbstract
    (@opts) ->
        super!
        @target = @opts.target
        @log = new Logger \SiemensS7Driver
        @conn = new NodeS7 {+silent}
        #@log.log "S7 Actor is created: #{@target.host}:#{@target.port}"
        @watches = {}
        @start!
        @log.todo "When do we stop?"
        @connected = no
        @on \connect, ~>
            @connected = yes

        @on \disconnect, ~>
            @connected = no

    prepare-one-read: (address) ->
        @conn.removeItems!  # remove all items to prepare one reading
        @conn.addItems address

    done-one-read: ->
        @conn.removeItems!
        @conn.addItems [address for address of @watches]  # re-add all items

    read: (handle, callback) ->
        @prepare-one-read handle.address
        err, data <~ @conn.readAllItems
        @done-one-read!
        value = data[handle.address] unless err
        callback err, handle.get-meaningful value

    write: (handle, value, callback) ->
        if @opts.readonly
            error = "READONLY, not writing the following: #{handle.address} <= #{value}"
            @log.warn error
            return callback error
        err <~ @conn.writeItems handle.address, value
        callback err

    start: ->
        @conn.initiateConnection @target, (err) ~>
            if err => return @log.log "we have an error: ", err
            @log.info bg-green "Connection is successful to: #{@target.host}:#{@target.port}"
            @start-read-poll!

    stop: ->
        @log.log "Closing the connection"
        <~ @conn.dropConnection
        @log.log "Connection closed"

    start-read-poll: !->
        @log.log "started read-poll"
        @prev-data = {}
        <~ :lo(op) ~>
            err, data <~ @conn.readAllItems
            if err
                @log.log "something went wrong while reading values"
                if @connected => @trigger \disconnect
            else
                @log.info "Read some data: ", data 
                unless @connected => @trigger \connect
                # detect and send changes
                for addr, _value of data
                    {handle, callback} = @watches[addr]
                    value = handle.get-meaningful _value
                    #@log.log "value: ", handle.topic, handle.address, value
                    if handle.prev? and abs(handle.prev - value) / value < (handle.threshold or 0.001)
                        #@log.info "Considered No-change: #{handle.prev} -> #{value}"
                        null
                    else
                        #@log.log "#{handle.topic}  is changed: -> #{value}"
                        callback err=null, value
                        handle.prev = value
            <~ sleep (@opts.period or 1500ms)
            lo(op)

    watch-changes: (handle, callback) ->
        @log.log "Adding address of #{handle.topic} (#{handle.address}) to the read poll."
        @watches[handle.address] = {handle, callback}
        @conn.addItems handle.address
