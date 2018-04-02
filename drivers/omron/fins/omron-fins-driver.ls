require! 'dcs': {EventEmitter, Signal, sleep, pack}
require! 'omron-fins': fins
require! 'prelude-ls': {chars, empty, reverse}
require! 'colors': {bg-yellow}
require! 'dcs/lib/memory-map': {bit-write, bit-test}

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

export class OmronFinsDriver extends EventEmitter
    (@opts={}) ->
        super!
        @target = {port: 9600, host: '192.168.250.1'} <<< @opts
        @read-signal = new Signal!
        @write-signal = new Signal!
        @timeout = 500ms

        console.log bg-yellow "Using #{@target.host}:#{@target.port}"
        @client = fins.FinsClient @target.port, @target.host

        @client.on \reply, (msg) ~>
            if msg.command is \0101
                #console.log "........got read reply: ", msg, @read-signal.waiting, @read-signal.should-run
                @read-signal.go msg
            else if msg.command is \0102
                #console.log "....got write reply: ", msg
                @write-signal.go msg
            else
                console.log "unknown msg.command: #{msg.command}"
                #console.log "reply: ", pack msg

    read: (address, amount, callback) ->
        {addr, type} = @parse-addr address
        #console.log "read address, type: ", addr, type
        if type is \bool
            err, res <~ @read-bit addr
            #console.log "read result of bit: err:", err, "res: ", res
            callback err, res
        else
            @read-byte addr, amount, callback

    write: (address, value, callback) ->
        {addr, type} = @parse-addr address
        if type is \bool
            #console.log "writing bit: word: ", addr.0, "bit" addr.1, "val: ", value
            err, res <~ @write-bit addr, value
            #console.log "write output: err, res: ", err, res
            callback err
        else
            #console.log "writing byte: ", addr, "val: ", value
            err, res <~ @write-byte addr, value
            #console.log "write output: err, res: ", err, res
            callback err


    debug-read: ->
        /* Test process  */
        console.log "started debug-read."
        address = "C100.2"
        x = false
        <~ :lo(op) ~>
            err, res <~ @read address, 1
            console.log "read value is: ", res
            x := not x
            <~ sleep 1500ms
            lo(op)


    debug: ->
        console.log "started debug"
        address = "C100.2"
        x = false
        <~ :lo(op) ~>
            console.log "writing: ", x
            err, res <~ @write address, x
            console.log "write ", if err => \FAILED else \OK
            err, res <~ @read address, 1
            console.log "read value is: ", res
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
        #console.log "curr", curr-value
        new-value = bit-write res, BIT_NUM, value
        err, res <~ @write-byte WORD_ADDR, new-value
        if err => return callback err
        #console.log "Write response: ", res
        callback err, res

    read-bit: (addr, callback) ->
        [WORD_ADDR, BIT_NUM] = addr
        err, res <~ @read-byte WORD_ADDR
        #console.log "read bit first read: ", err, res
        if err => return callback err
        bit-value = bit-test res, BIT_NUM
        callback err, bit-value

    write-byte: (addr, value, callback) ->
        # TODO: https://github.com/patrick--/node-omron-fins/issues/13
        err, bytes <~ @client.write addr, value
        if err => ...
        @write-signal.clear!
        err, msg <~ @write-signal.wait @timeout
        #console.log "write message response: #{pack msg}"
        callback err, msg

    read-byte: (addr, count, callback) ->
        unless callback
            callback = count
            count = 1
        #console.log "Reading byte: addr: ", addr, "count: ", count
        _err, bytes <~ @client.read addr, count
        if _err
            console.log "read failed : ", _err
            return callback _err
        @read-signal.clear!
        _err, msg <~ @read-signal.wait @timeout
        #console.log "read reply: ", _err, msg
        unless _err
            try
                value = if count is 1
                    msg.values.0
                else
                    msg.values
            catch
                console.error "------------------------"
                console.log "msg was: ", msg
                throw e
        callback _err, value


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
            else
                # like "C0100", word
                return do
                    type: \word
                    addr: addr
        else
            console.log "Typeof addr: ", (typeof! addr), addr
