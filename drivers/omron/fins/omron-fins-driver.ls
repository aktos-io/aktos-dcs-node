require! 'dcs': {EventEmitter, Logger, Signal, sleep, pack}
require! 'omron-fins': fins
require! 'prelude-ls': {chars, empty, reverse, unique}
require! 'colors': {bg-yellow}
require! 'dcs/lib/memory-map': {bit-write, bit-test}
require! '../../driver-abstract': {DriverAbstract}

/* ***********************************************

command:
    * read
    * write

address:
    either "WORD_ADDR" or "WORD_ADDR.BIT_NUM" format

value:
    if command is 'write' =>
        value to write to
        * single (write to the address)
        * array (write starting from the address)
    if command is 'read'  =>
        if bitwise => ignored
        if word => number of addresses to read

*****************************************************/

export class OmronFinsDriver extends DriverAbstract
    (@opts={}) ->
        super!
        @log = new Logger \OmronFinsDriver
        @target = {port: 9600, host: '192.168.250.1'} <<< @opts
        @read-signal = new Signal!
        @write-signal = new Signal!
        @busy = no
        @queue = []
        @max-busy = 2300ms # 400ms
        @timeout = 2000ms  # 100ms
        @watches = {}

        @connected = no
        @on \disconnect, ~>
            @log.info "Driver says we are disconnected"
            @connected := no

        @on \connect, ~>
            @log.info "Driver says: we are connected."
            @connected := yes
            @start-polling!

        @log.log bg-yellow "Using #{@target.host}:#{@target.port}"
        @client = fins.FinsClient @target.port, @target.host

        @client.on \reply, (msg) ~>
            if msg.command is \0101
                #@log.log "........got read reply: ", msg, @read-signal.waiting, @read-signal.should-run
                @read-signal.go msg
            else if msg.command is \0102
                #@log.log "....got write reply: ", msg
                @write-signal.go msg
            else
                @log.warn "unknown msg.command: #{msg.command}"
                #@log.log "reply: ", pack msg

        @exec-seq = 0
        sleep 1000ms, ~>
            @log.info "Starting initial heartbeating."
            @check-heartbeating!

    check-heartbeating: ->
        if @heartbeating
            ...

        @heartbeating = yes
        @log.log "Checking heartbeat with PLC"
        <~ :lo(op) ~>
            console.log "callbacks: ", @read-signal.callbacks
            err, res <~ @read {address: \C0}
            @log.log "Response of heartbeat: ", err, res
            unless err
                return op!
            @log.log "Retrying in 5000ms"
            <~ sleep 5000ms
            lo(op)
        @log.log "Heartbeating says: connected!"
        @trigger \connect
        @heartbeating = no


    exec: (method, ...args, callback) !->
        if @busy
            @log.info "busy! adding to queue. queue size: ", @queue.length, method, args.0.address
            @queue.push [method, args, callback]
            return
        @busy = yes
        @exec-seq++
        #@log.log "executing seq:#{@exec-seq}, method: #{method}"

        timed-out = no
        succeeded = no
        x = sleep @max-busy, ~>
            timed-out := yes
            @log.log "okay, timed out?"
            callback err="max-busy is reached for seq:#{@exec-seq}"
            @exec-next!
            if succeeded
                @log.err "how come this timeout is exceeded but overall call is succeeded?"
                return

        retry = 3
        <~ :lo(op) ~>
            err, ...ret <~ @[method] ...args
            if err
                @log.log "seq:#{@exec-seq} method (#{method}) returned error, retrying..."
                # retry last command
                if timed-out
                    @log.log "seq:#{@exec-seq} giving up retrying because timeout window seems exceeded"
                    return
                if --retry <= 0
                    @log.log "seq:#{@exec-seq} reached retry limit, giving up."
                    try clear-timeout x
                    return op!
                <~ sleep 5ms
                @log.log "seq:#{@exec-seq} executing a retry."
                lo(op)
            else
                # command successful; cleanup and return the value
                succeeded := yes
                try clear-timeout x
                callback err, ...ret
                @exec-next!
        @log.err "seq:#{@exec-seq} All retries are failed!"
        callback err="seq:#{@exec-seq} all retries are failed!"
        @exec-next!

    exec-next: ->
        @busy = no
        if @queue.length > 0
            next = @queue.shift!
            @log.info "Running from queue, queue size: ", @queue.length
            <~ sleep 0
            @exec next.0, ...next.1, next.2

    read: (...x, callback) ->
        @exec \__read, ...x, callback

    write: (...x, callback) ->
        @exec \__write, ...x, callback

    __read: (handle, callback) ->
        {addr, type, bit, count} = @parse-addr handle
        #@log.log "Reading byte: addr: ", addr, "type:", type, "count: ", count
        _err, bytes <~ @client.read addr, count
        if _err
            @log.err "read request failed : ", _err
            return callback _err
        @read-signal.reset!
        #@log.log "Waiting for read signal. timeout: ", @timeout
        err, msg <~ @read-signal.wait @timeout
        if err
            @log.err "read reply: ", err, msg
            return callback err

        value = msg.values
        value = value.0 if count is 1
        switch type
        | \bool => return callback err, (bit-test value, bit)
        | \word => return callback err, value

    __write: (handle, value, callback) ->
        {addr, type, count, bit} = @parse-addr handle
        <~ :lo(op) ~>
            if type is \bool
                #@log.log "writing bit: word: ", addr.0, "bit" addr.1, "val: ", value
                err, curr-value <~ @__read {address: addr}
                if err => return callback err
                #@log.log "curr", curr-value
                new-value = bit-write curr-value, bit, value
                value := new-value
                return op!
            else
                return op!

        # TODO: https://github.com/patrick--/node-omron-fins/issues/13
        err, bytes <~ @client.write addr, value
        if err => return callback err
        @write-signal.reset!
        err, msg <~ @write-signal.wait @timeout
        #@log.log "write message response: #{pack msg}"
        callback err, msg

    watch-changes: (handle, callback) ->
        #@log.todo "Received a watch change for #{handle.topic}"
        @watches[handle.address] = {handle, callback}

    start-polling: ->
        @log.info "Started watching changes: Polling"
        reduced-areas = []
        for name, watch of @watches
            {addr} = @parse-addr watch.handle
            reduced-areas ++= addr

        #@log.warn "Reduced areas (before unique): ", reduced-areas
        #@log.warn "Reduced areas (after unique): ", unique reduced-areas
        if empty reduced-areas
            reduced-areas.push \C0  # to be used for heartbeating purposes
        reduced-areas = unique reduced-areas
        index = 0
        <~ :lo(op) ~>
            area = reduced-areas[index]
            #@log.log "Reading memory: #{area}"
            err, res <~ @read {address: area}
            #console.log "polling read output: ", err, res
            if err
                @log.err "Something went wrong while reading #{area}", err
                return op! # => break

            for name, watch of @watches
                handle = watch.handle
                parsed = handle |> @parse-addr
                if area is parsed.addr
                    #@log.log "handle: #{watch.handle.address} can be read from: #{area}"
                    if parsed.type is \bool
                        bit-value = bit-test res, parsed.bit
                        if handle.prev? and handle.prev is bit-value
                            #@log.log "no change (bit)...", bit-value
                            null
                        else
                            #@log.log "...bit value is: ", bit-value
                            watch.callback err=null, bit-value
                            handle.prev = bit-value
                    else
                        if handle.prev? and handle.prev is res
                            #@log.log "no change (word)...", res
                            null
                        else
                            #@log.log "...word value is: ", res
                            watch.callback err=null, res
                            handle.prev = res
            index++
            if index is reduced-areas.length
                # start from beginning
                index := 0
            <~ sleep 200ms
            lo(op)
        @log.warn "Stopping polling, starting to check only heartbeating"
        @trigger \disconnect
        @check-heartbeating!
        for let name, watch of @watches
            @log.info "sending error info"
            watch.callback err="stopped loop"


    parse-addr: (handle) ->
        [addr, bit] = handle.address.split '.'
        if bit?
            # like "C0100.05", bool
            return do
                type: \bool
                addr: addr
                bit: parse-int bit
                count: 1
        else
            # like "C0100", word
            return do
                type: \word
                addr: addr
                count: 1
