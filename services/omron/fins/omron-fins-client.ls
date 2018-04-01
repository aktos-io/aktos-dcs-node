require! 'dcs': {Actor, Signal, sleep, pack}
require! 'omron-fins': fins
require! 'prelude-ls': {chars, empty, reverse}
require! 'colors': {bg-yellow}
require! 'dcs/lib/memory-map': {bit-write, bit-test}


'''
DCS Message API:
--------------------------

### Write to a block:

    {{topic}}.write, payload: {val: value-to-write}

### Read a block:

    {{topic}}.read, payload: null

'''


export class OmronFinsClient extends Actor
    (@opts={}) ->
        super @opts.name or 'OmronFinsClient'

        @target = {port: 9600, host: '192.168.250.1'} <<< @opts
        @read-signal = new Signal!
        @write-signal = new Signal!
        @timeout = 5000ms

        @client = null
        @on \reconnect, ~>
            @log.log bg-yellow "Using #{@target.host}:#{@target.port}"
            @client := fins.FinsClient @target.port, @target.host
        @trigger \reconnect

        @client.on \reply, (msg) ~>
            if msg.command is \0101
                @read-signal.go msg
            else if msg.command is \0102
                @write-signal.go msg
            else
                @log.log "unknown msg.command: #{msg.command}"
                #console.log "reply: ", pack msg

    action: ->
        # for debugging purposes
        #@debug-test!
        ...

        @subscribe "#{@name}.**"
        @on \data, (msg) ~>
            ...
            # exec-command here

    exec-command: (command, address, value, callback) ->
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
        try
            {addr, type} = @parse-addr address
            #console.log "command: ", command, "addr", addr
            #    , "type:" , type, "value: ", value
            switch command
            | \write =>
                if type is \bool
                    #console.log "writing bit: ", addr.0, addr.1, "val: ", value.val
                    err, res <~ @write-bit addr, value
                    callback {err, res: (unless err => value)}
                else
                    #console.log "writing byte: ", addr.addr, "val: ", value.val
                    err, res <~ @write-byte addr, value
                    callback {err, res: (unless err => value)}
            | \read =>
                if type is \bool
                    err, res <~ @read-bit addr
                    callback {err, res}
                else
                    amount = value
                    err, res <~ @read-byte addr, amount
                    callback {err, res}
        catch
            throw e

    debug-test: ->
        /* Test process  */
        address = "C100"
        bit-no = 0
        x = true
        <~ :lo(op) ~>
            console.log "writing: ", x
            err, res <~ @write-bit [address, bit-no], x
            console.log "write ", if err => \FAILED else \OK
            err, res <~ @read-bit [address, bit-no]
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
        try
            curr-value = res.values.0
        catch
            @trigger \reconnect
            return callback {res, message: e, stage: "First read value"}
        #console.log "curr", curr-value
        new-value = bit-write curr-value, BIT_NUM, value
        err, res <~ @write-byte WORD_ADDR, new-value
        if err => return callback err
        console.log "Write response: ", res
        err, res <~ @read-byte WORD_ADDR
        try
            _curr = res.values.0
        catch
            @trigger \reconnect
            return callback {res, message: e, stage: "Read back value"}
        if _curr isnt new-value
            @trigger \reconnect
            return callback "Value does not match with written one"
        callback err, res

    read-bit: (addr, callback) ->
        [WORD_ADDR, BIT_NUM] = addr
        err, res <~ @read-byte WORD_ADDR
        if err => return callback err
        try
            curr-value = res.values.0
        catch
            return callback {res, message: e, stage: "Read Bit Stage"}
        #console.log "curr", curr-value
        bit-value = bit-test curr-value, BIT_NUM
        callback err, bit-value

    write-byte: (addr, value, callback) ->
        # TODO: https://github.com/patrick--/node-omron-fins/issues/13
        err, bytes <~ @client.write addr, value
        if err => ...
        err, msg <~ @write-signal.wait @timeout
        #console.log "write message response: #{pack msg}"
        callback err, msg

    read-byte: (addr, count, callback) ->
        unless callback
            callback = count
            count = 1
        err, bytes <~ @client.read addr, count
        if err => ...
        err, msg <~ @read-signal.wait @timeout
        callback err, msg


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
