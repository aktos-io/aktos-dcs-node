require! 'dcs': {Actor}
require! './nodeS7': nodes7
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {at, split}

split-topic = split '.'

export class S7Actor extends Actor
    (opts) ->
        @opts = opts
        super @opts.name


        # S7 client
        @conn = new nodes7 {+silent}
        @addr-to-name = {}

        # actor stuff
        @on-kill (reason) ~>
            @log.log "TODO: close the connection"

        @on-receive (msg) ~>
            io-name = split-topic msg.topic |> at 1
            #@log.log "got msg: write #{msg.payload} -> #{io-name}"
            io-addr = @opts.memory-map[io-name]
            @log.log "Writing: ", msg.payload, "to: ", io-addr
            err <~ @conn.writeItems io-addr, msg.payload
            @log.err "something went wrong while writing: ", err if err



    action: ->
        @log.log "S7 Actor is created: ", @opts.target, @opts.name
        @start!

    start: ->
        @connect ~>
            @start-read-poll!
        # add memory map for poll list
        for name, addr of @opts.memory-map
            @add-to-read-poll addr
            @addr-to-name[addr] = name

    start-read-poll: ->
        @log.log "started read-poll"
        prev-data = {}
        <~ :lo(op) ~>
            err, data <~ @conn.readAllItems
            @log.log "something went wrong while reading values" if err
            for prev-io-addr, prev-io-val of prev-data
                for io-addr, io-val of data when io-addr is prev-io-addr
                    if io-val isnt prev-io-val
                        @send io-val, "#{@name}.#{@addr-to-name[io-addr]}"

            prev-data := data
            <~ sleep 100ms
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
