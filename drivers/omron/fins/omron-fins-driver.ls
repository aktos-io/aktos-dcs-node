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
        @timeout = 500ms
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

        sleep 1000ms, ~>
            @log.info "Starting initial heartbeating."
            @check-heartbeating!

        @busy = no
        @queue = []
        @max-busy = 300ms

    run: (method, ...args, callback) !->
        if @busy
            #@log.info "busy! adding to queue."
            @queue.push [method, args, callback]
            return
        #@log.log "we are now going busy, args: ", ...args
        @busy = yes
        x = sleep @max-busy, ~>
            @log.warn "FORCE RUNNNING NEXT!"
            callback err="Forcing running next."
            @next!
        @[method] ...args, (...ret) ~>
            if x
                clear-timeout x
                callback ...ret
                #@log.log "we are free"
                @next!
            else
                @log.err "what happened here?"

    next: ->
        @busy = no
        if @queue.length > 0
            #@log.info "Running from queue"
            next = @queue.shift!
            @run next.0, ...next.1, next.2

    read: (handle, callback) ->
        retry = 3
        <~ :lo(op) ~>
            err, res <~ @__read handle
            unless err
                return callback err, res
            if retry-- is 0
                return op!
            @log.log "retrying read: left #{retry}"
            lo(op)
        @log.err "All retries are failed!"
        callback err="retry failed"

    __read: (handle, callback) ->
        {addr, type} = @parse-addr handle.address
        #@log.log "read address, type: ", addr, type
        if type is \bool
            err, res <~ @read-bit addr
            #@log.log "read result of bit: err:", err, "res: ", res
            callback err, res
        else
            err, res <~ @read-byte addr, (handle.amount or 1)
            callback err, res

    write: (handle, value, callback) ->
        {addr, type} = @parse-addr handle.address
        if type is \bool
            #@log.log "writing bit: word: ", addr.0, "bit" addr.1, "val: ", value
            err, res <~ @write-bit addr, value
            #@log.log "write output: err, res: ", err, res
            callback err
        else
            #@log.log "writing byte: ", addr, "val: ", value
            err, res <~ @write-byte addr, value
            #@log.log "write output: err, res: ", err, res
            callback err


    debug: ->
        @log.log "started debug"
        address = "C100.2"
        x = false
        <~ :lo(op) ~>
            @log.log "writing: ", x
            err, res <~ @write address, x
            @log.log "write ", if err => \FAILED else \OK
            err, res <~ @read address, 1
            @log.log "read value is: ", res
            x := not x
            <~ sleep 1500ms
            lo(op)


    write-bit: (addr, value, callback) ->
        # --------------------------------------------------------------
        # TODO: https://github.com/patrick--/node-omron-fins/issues/13
        # --------------------------------------------------------------
        # addr = [WORD_ADDR, BIT_NUM]
        # -------------------------------
        # set BIT_NUMth bit to `value`,
        # write new value back
        [WORD_ADDR, BIT_NUM] = addr
        err, res <~ @read-byte WORD_ADDR
        if err => return callback err
        #@log.log "curr", curr-value
        new-value = bit-write res, BIT_NUM, value
        err, res <~ @write-byte WORD_ADDR, new-value
        if err => return callback err
        #@log.log "Write response: ", res
        callback err, res

    read-bit: (addr, callback) ->
        [WORD_ADDR, BIT_NUM] = addr
        err, res <~ @read-byte WORD_ADDR
        #@log.log "read bit first read: ", err, res
        if err => return callback err
        bit-value = bit-test res, BIT_NUM
        callback err, bit-value

    write-byte: (addr, value, callback) ->
        # TODO: https://github.com/patrick--/node-omron-fins/issues/13
        @write-signal.reset!
        do
            err, bytes <~ @client.write addr, value
            if err => ...
        err, msg <~ @write-signal.wait @timeout
        #@log.log "write message response: #{pack msg}"
        callback err, msg

    read-byte: (...args, callback) ->
        @run \_readByte, ...args, callback

    _read-byte: (addr, count, callback) ->
        unless callback
            callback = count
            count = 1

        #@log.log "Reading byte: addr: ", addr, "count: ", count
        @read-signal.reset!
        _err, bytes <~ @client.read addr, (count or 1)
        if _err
            @log.err "read request failed : ", _err
            return callback _err
        #@log.log "Waiting for read signal. timeout: ", @timeout
        _err, msg <~ @read-signal.wait @timeout
        if _err
            @log.err "read reply: ", _err, msg
        value = null
        unless _err
            try
                value = if count is 1
                    msg.values.0
                else
                    msg.values
            catch
                @log.error "------------------------"
                @log.log "msg was: ", msg
                throw e
        callback _err, value

    watch-changes: (handle, callback) ->
        #@log.todo "Received a watch change for #{handle.topic}"
        @watches[handle.address] = {handle, callback}

    start-polling: ->
        @log.info "Started watching changes: Polling"
        reduced-areas = []
        for name, watch of @watches
            {memory} = @parse-addr watch.handle.address
            reduced-areas ++= memory

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
            if err
                @log.err "Something went wrong while reading #{area}", err
                return op! # => break

            for name, watch of @watches
                handle = watch.handle
                parsed = handle.address |> @parse-addr
                if area in parsed.memory
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
            <~ sleep 200ms  # WARNING: Do not set a too short timeout! (as a Workaround)
            lo(op)
        @log.warn "Stopping polling, starting to check only heartbeating"
        @trigger \disconnect
        @check-heartbeating!

    check-heartbeating: ->
        @log.log "Checking heartbeat with PLC"
        <~ :lo(op) ~>
            err, res <~ @_read-byte \C0, 1
            @log.log "Response of heartbeat: ", err, res
            unless err
                return op!
            @log.log "Retrying in 5000ms"
            <~ sleep 5000ms
            lo(op)
        @log.log "Heartbeating says: connected!"
        @trigger \connect

    parse-addr: (addr) ->
        /* return type:

            {
                addr: Array
                value: WRITE value or amount of words to READ
            }
        */
        if typeof! addr is \Array
            # like ["C0100", 5]
            return do
                type: \bool
                addr: addr
        if typeof! addr is \String
            [addr, bit] = addr.split '.'
            if bit?
                # like "C0100.05", bool
                return do
                    type: \bool
                    addr: [addr, parse-int bit]
                    bit: parse-int bit
                    memory: [addr]
            else
                # like "C0100", word
                return do
                    type: \word
                    addr: addr
                    memory: [addr]
        else
            @log.log "Typeof addr: ", (typeof! addr), addr
