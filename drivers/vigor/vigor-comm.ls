require! '../../lib/event-emitter': {EventEmitter}
require! 'prelude-ls': {map, flatten, split-at, compact}

STX = 0x02
ETX = 0x03
ACK = 0x06

as-hex = (x) ->
    x.split ' ' .map (-> parse-int "0x#{it}")

last-chars = (n, str) -->
    str.substr -n

last-two-chars = last-chars 2

last-four-chars = last-chars 4

zero-pad = (n, str) -->
    last-chars n, "#{'0' * n}#{str}"

to-hexstr = (num, padding) ->
    # 11 => "b"
    # 11, 2 => "0b"
    # 18 => "12"
    if typeof! num isnt \Number
        throw "num must be number."
    hex = num.to-string 16
    unless padding
        return hex
    else
        return zero-pad padding, hex

str-to-arr = (.split "")

to-ascii = (.map (.to-upper-case!.char-code-at 0))

to-str = -> String.from-char-code it

as-ascii-arr = (-> it |> str-to-arr |> to-ascii)

ascii-to-str = ->
    it.map(to-str).join('')

ascii-to-int = (x, base=10)->
    x |> ascii-to-str |> parse-int _, base

checksum = (arr) ->
    # see "How to calculate checksum of a protocol" section
    a = 0
    for arr
        continue if .. in [STX, ACK]
        a += ..
        break if .. is ETX
    a
        |> to-hexstr
        |> last-two-chars
        |> (.to-upper-case!)
        |> as-ascii-arr

# checksum tests
_visual = -> it |> map to-hexstr |> (.join ' ')
y = as-hex "02 30 30 37 30 30 34 31 34 03 39 33"
ch = y |> checksum |> _visual
expected = "39 33"
if ch isnt expected => throw "Checksum does not calculated correctly: expected: '#{expected}', got: #{ch}"

y = as-hex "02 30 30 35 31 30 30 38 31 30 31 03 46 33"
ch = y |> checksum |> _visual
expected = "46 33"
if ch isnt expected => throw "Checksum does not calculated correctly: expected: '#{expected}', got: #{ch}"

# See "Command list" in the datasheet
COMMANDS =
    read: "51"
    write: "61"
    force-on: "70"
    force-off: "71"

for k, v of COMMANDS
    COMMANDS[k] = v |> zero-pad(2) |> as-ascii-arr

STATUS_CODES =
    "00": "OK"
    "10": "Ascii code error"
    "11": "Checksum error"
    "12": "Command undefined"
    "14": "Stop, parity, frame error or overrun"
    "28": "Address out of range"

START_ADDRESS = {
    'x': 0x0,          # input relay (x0..x777)
    'y': 0x40,         # output relay (y0..y777)
    'm': 0x80,         # auxilary relay (m0..m5119)
    's': 0x300,        # step relay (s0..s999)
    'tcon': 0x380,     # timer contact (t0..t255)
    'ccon': 0x3a0,     # counter contact (c0..c255)
    'srel': 0x3e0,     # special relay (m9000..m9255)
    'tcoil': 0x780,    # timer coil (t0..t255)
    'ccoil': 0x7a0,    # counter coil (c0..c255)
    'tcur': 0x1400,    # timer current value (t0..t255) (16 bit)
    'sreg': 0x1600,    # special register (d9000..d9255) (16 bit)
    'cval1': 0X1800,   # current value (c0..c199) (32 bit)
    'cval2': 0X1a00,   # current value (c200..c255) (32 bit)
    'conval': 0x1c00,  # content value (d0..d8191) (16 bit)
    }

export class VigorComm extends EventEmitter
    (opts) ->
        super!
        @transport = opts.transport

        @station-number = opts.station-number
        @recv = []
        bytes-after-etx = 2 # according to datasheet

        checksum-len = 2
        i = null
        @transport.on \data, (data) ~>
            # TODO: timeout should be 300ms between data portions
            for data
                if .. is ETX
                    # we expect 2 more bytes (for checksum)
                    i := checksum-len
                else if i?
                    # this is one of last two bytes
                    i--
                @recv.push ..
                if i is 0
                    # fire @receive handler when a full telegram is received
                    @receive @recv
                    @recv := []
                    i := null

        @queue = []

    receive: (telegram) ->
        #console.log "received telegram: ", ascii-to-str telegram
        try
            res = @validate telegram
            err = null
        catch
            res = null
            err = e

        @receive-handler? err, res
        @receive-handler = null
        @last = null
        @_executing = no
        if @queue.length > 0
            @execute!

    validate: (telegram) ->
        # validates the telegram, returns containing data if passes
        if telegram.0 isnt ACK
            throw "Response is not ACK"

        node-addr = ascii-to-int [telegram.1, telegram.2]
        if node-addr isnt @station-number
            throw "Station number is not correct"

        sent-func-code = ascii-to-str [@last.3, @last.4]
        recv-func-code = ascii-to-str [telegram.3, telegram.4]
        if sent-func-code isnt recv-func-code
            throw "Unexpected function code in response: #{recv-func-code}"

        err-code = ascii-to-str [telegram.5, telegram.6]
        unless err-code is "00"
            throw "Non-zero error returned: #{STATUS_CODES[err-code]}"

        check-code = telegram.slice telegram.length - 2
        if check-code.join('') isnt checksum(telegram).join('')
            throw "Checksum is not correct"

        if telegram.length > 10
            # this is a read response
            raw-data = telegram.splice (6 + 1), (telegram.length - 1 - 3 - 6)
            bytes = []
            for i from 0 til raw-data.length by 2
                bytes.push ascii-to-int [raw-data[i], raw-data[i+1]], 16
            return bytes
        else
            return null

    make-telegram: (cmd, start-addr, length, data) ->
        # format: STX + STATION_NUM + COMMAND + START_ADDR + LENGTH + DATA? + ETX + CHECKSUM
        STATION_NUM = @station-number
            |> to-hexstr _, 2
            |> as-ascii-arr
        START_ADDR = start-addr
            |> to-hexstr _, 4
            |> as-ascii-arr
        LENGTH = length
            |> to-hexstr _, 2
            |> as-ascii-arr
        DATA = unless data
            null
        else
            data.map (-> it |> to-hexstr _, 2 |> as-ascii-arr)
        _telegram = flatten compact [STX, STATION_NUM, COMMANDS[cmd], START_ADDR, LENGTH, DATA, ETX]
        return flatten _telegram ++ checksum(_telegram)

    execute: (query) ->
        if query
            @queue.push that

        unless @_executing
            @_executing = yes
            [telegram, handler] = @queue.shift!
            @last = telegram
            @receive-handler = handler
            #console.log "sending telegram: ", telegram.map((-> to-hexstr it, 2)).join(' ')
            @transport.write @last

    read: (name, offset, length, handler) ->
        # rw: "read" or "write"
        # start-addr: number or name of predefined memory name
        telegram = @make-telegram "read", (START_ADDRESS[name] + offset), length
        @execute [telegram, handler]

    write: (name, offset, data, callback) ->
        # data is an array of bytes
        # name is one of "x, y, m ..."
        telegram = @make-telegram "write", (START_ADDRESS[name] + offset), data.length, data
        @execute [telegram, callback]

    bit-telegram: (cmd, name, component-num) ->
        STATION_NUM = @station-number
            |> to-hexstr _, 2
            |> as-ascii-arr

        byte-offset = parse-int component-num / 8
        bit-offset = component-num % 8
        BIT_ADDR = ((START_ADDRESS[name] + byte-offset) * 8) + bit-offset
            |> to-hexstr _, 4
            |> as-ascii-arr
        _telegram = flatten [STX, STATION_NUM, COMMANDS[cmd], BIT_ADDR, ETX]
        return flatten _telegram ++ checksum(_telegram)

    bit-read: (io, callback) ->
        [name, num] = split-at 1, io
        num = parse-int num
        byte-offset = parse-int num / 8
        bit-offset = num % 8
        @read name, byte-offset, 1, (err, res) ->
            unless err
                res = res .>>. bit-offset
            callback err, res

    bit-write: (io, val, callback) ->
        [name, num] = split-at 1, io
        num = parse-int num
        cmd = if val => "forceOn" else "forceOff"
        telegram = @bit-telegram cmd, name, num
        @execute [telegram, callback]


export serial-settings =
    port: '/dev/ttyUSB0'
    baudrate: 19200
    dataBits: 7
    parity: 'even'
    stopBits: 1
    split-at: null

# for debugging purposes
if require.main is module
    require! '../../transports/serial-port': {SerialPortTransport}
    require! '../../': {sleep}

    ser = new SerialPortTransport serial-settings

    <~ ser.once \connect
    v = new VigorComm do
        transport: ser
        station-number: 0

    v.read "y", 0, 1, (err, data) ->
        console.log "response of y0", data

    v.write "y", 3, [0xaa, 0x55], (err) ->
        console.log "write res: ", err

    <~ sleep 1000ms
    v.write "y", 3, [0, 0], (err) ->
        console.log "write res: ", err

    i = true
    <~ :lo(op) ~>
        v.bit-write "y3", i, (err) ->
            console.log "bit write err:", err

        v.bit-read "y3", (err, data) ->
            console.log "bit get: ", err, data

        <~ sleep 1000ms
        i := not i
        lo(op)
