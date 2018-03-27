require! 'dcs': {Actor, Signal, sleep, pack}
require! 'omron-fins': fins
require! 'prelude-ls': {chars, reverse}
require! 'colors': {bg-yellow}
require! 'dcs/lib/memory-map': {bit-write, bit-test}

'''
DCS Message API:
--------------------------

### Write to a block:

    write:
        addr: (see parse-addr)
        val: value to write

### Read a block:

    read:
        addr: (see parse-addr)

'''

parse-addr = (addr) ->
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



export class OmronFinsClient extends Actor
    (@opts={}) ->
        @name = @opts.name or throw 'Fins Client need a name to be subscribed with'
        super @name
        @subscribe "#{@name}.**"

        @target = {port: 9600, host: '192.168.250.1'} <<< @opts
        @log.log bg-yellow "Using #{@target.host}:#{@target.port}"
        @client = fins.FinsClient @target.port, @target.host
        @read-signal = new Signal!
        @write-signal = new Signal!
        @timeout = 5000ms

        @client.on \reply, (msg) ~>
            if msg.command is \0101
                @read-signal.go msg
            else if msg.command is \0102
                @write-signal.go msg
            else
                @log.log "unknown msg.command: #{msg.command}"
                console.log "reply: ", pack msg

    action: ->
        # for debugging purposes
        #@debug-test!

        @on \data, (msg) ~>
            for command, value of msg.payload
                try
                    {addr, type} = parse-addr value.addr
                    #console.log "command: ", command, "addr", addr,
                    # "type:" , type, "value: ", value.val
                    switch command
                    | \write =>
                        if type is \bool
                            #console.log "writing bit: ", addr.0, addr.1, "val: ", value.val
                            err, res <~ @write-bit addr, value.val
                            @send-response msg, {err, res}
                        else
                            #console.log "writing byte: ", addr.addr, "val: ", value.val
                            err, res <~ @write-byte addr, value.val
                            @send-response msg, {err, res}
                    | \read =>
                        if type is \bool
                            err, res <~ @read-bit addr, value.val
                            @send-response msg, {err, res}
                        else
                            err, res <~ @read-byte addr, value.val
                            @send-response msg, {err, res}

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
        # addr = [WORD_ADDR, BIT_NUM]
        # -------------------------------
        # set BIT_NUMth bit to `value`,
        # write new value back
        [WORD_ADDR, BIT_NUM] = addr
        err, res <~ @read-byte WORD_ADDR
        if err => return callback err
        curr-value = res.values.0
        #console.log "curr", curr-value
        new-value = bit-write curr-value, BIT_NUM, value
        err, res <~ @write-byte WORD_ADDR, new-value
        callback err, res

    read-bit: (addr, callback) ->
        [WORD_ADDR, BIT_NUM] = addr
        err, res <~ @read-byte WORD_ADDR
        if err => return callback err
        curr-value = res.values.0
        #console.log "curr", curr-value
        bit-value = bit-test curr-value, BIT_NUM
        callback err, bit-value

    write-byte: (addr, value, callback) ->
        err, bytes <~ @client.write addr, value
        err, msg <~ @write-signal.wait @timeout
        #console.log "write message response: #{pack msg}"
        callback err, msg

    read-byte: (addr, count, callback) ->
        unless callback
            callback = count
            count = 1
        err, bytes <~ @client.read addr, count
        err, msg <~ @read-signal.wait @timeout
        callback err, msg
