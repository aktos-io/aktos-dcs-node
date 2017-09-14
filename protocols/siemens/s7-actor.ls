require! 'dcs': {Actor}
require! './nodeS7': NodeS7
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {at, split}
require! 'colors': {yellow, red, green}
require! 'aea/memory-map': {MemoryMap}

export class S7Actor extends Actor
    (@opts) ->
        super @opts.name

    action: ->
        @debug = @opts.debug

        @topic-prefix = @opts.name
        if @opts.public
            @topic-prefix = "public.#{@topic-prefix}"
        @subscribe "#{@topic-prefix}.**"


        @log.log-green "Subscriptions:", @subscriptions

        @io-map = new MemoryMap @opts.memory-map, do
            prefix: "#{@topic-prefix}."

        # S7 client
        @conn = new NodeS7 {+silent}
        @addr-to-name = {}
        @first-read-done = no

        # actor stuff
        @on \kill, (reason) ~>
            @log.log "Closing the connection"
            <~ @conn.dropConnection
            @log.log "Connection closed"

        @on \data, (msg) ~>
            io-addr = @io-map.get-addr msg.topic
            if @opts.readonly
                @log.log (yellow "READONLY, not writing the following:"), "#{io-addr}: #{msg.payload}"
                return
            @log.log "Writing: ", msg.payload, "(#{typeof! msg.payload}) to: ", io-addr

            return @log.log "DEBUG, NOT WRITING!"
            err <~ @conn.writeItems io-addr, msg.payload
            @log.err "something went wrong while writing: ", err if err

        @on \update, (msg) ->
            @log.log "Siemens actor received an update request!"
            for key, val of @prev-data
                @prev-data[key] = void

        @log.log "S7 Actor is created: ", @opts.target, @opts.name
        @start!

    start: ->
        @connect ~>
            @start-read-poll!
        # add memory map for poll list
        for addr in @io-map.get-all-addr!
            @log.log "adding #{addr} to polling list"
            @add-to-read-poll addr

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


    connect: (callback) ->
        @conn.initiateConnection @opts.target, (err) ~>
            if err
                @log.log "we have an error: ", err
                @kill 'SIEMENS_CONN_ERR'
            else
                callback!


    add-to-read-poll: (addr) ->
        @log.log "Adding address of #{addr} to the read poll."
        @conn.addItems addr
