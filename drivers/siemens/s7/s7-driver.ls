require! 'nodes7': NodeS7
require! 'dcs': {EventEmitter, Logger, sleep, pack}
require! 'dcs/lib/memory-map': {bit-write, bit-test}
require! '../../driver-abstract': {DriverAbstract}


export class SiemensS7Driver extends DriverAbstract
    (@opts) ->
        super!
        @log = new Logger \SiemensS7Driver
        # S7 client
        @conn = new NodeS7 {+silent}
        @log.log "S7 Actor is created: ", @opts.target, @opts.name
        @start!

    read: (handle, callback) ->
        console.log "trying to read #{handle.topic}"
        callback!

    write: (handle, value, callback) ->
        console.log "trying to write #{handle.topic}"
        callback!
        return

        if @opts.readonly
            @log.log (yellow "READONLY, not writing the following:"), "#{io-addr}: #{msg.payload}"
            return
        @log.log "Writing: ", msg.payload, "(#{typeof! msg.payload}) to: ", io-addr

        return @log.log "DEBUG, NOT WRITING!"
        err <~ @conn.writeItems io-addr, msg.payload
        @log.err "something went wrong while writing: ", err if err


    start: ->
        @conn.initiateConnection @opts.target, (err) ~>
            if err => return @log.log "we have an error: ", err

    stop: ->
        @log.log "Closing the connection"
        <~ @conn.dropConnection
        @log.log "Connection closed"


    start-read-poll: ->
        @log.log "started read-poll"
        @prev-data = {}
        <~ :lo(op) ~>
            err, data <~ @conn.readAllItems
            if err
                @log.log "something went wrong while reading values"
                @first-read-done = no
            for prev-io-addr, prev-io-val of @prev-data
                for io-addr, io-val of data when io-addr is prev-io-addr
                    if io-val isnt prev-io-val
                        x = @io-map.get-meaningful io-addr, io-val
                        if not @first-read-done or @debug
                            @first-read-done = yes
                            @log.log (yellow '[ DEBUG (first read)]'), "Read: #{x.name} (#{io-addr}) = #{x.value}"

                        @send x.value, "#{@topic-prefix}.#{x.name}"

            @prev-data = data
            <~ sleep (@opts.period or 500ms)
            lo(op)


    add-to-read-poll: (addr) ->
        @log.log "Adding address of #{addr} to the read poll."
        @conn.addItems addr

    watch-changes: (handle, callback) ->
        @log.warn "not watching #{handle.topic}"
