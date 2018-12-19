require! '../driver-abstract': {DriverAbstract}
require! '../../': {sleep}
require! '../../transports/serial-port': {SerialPortTransport}
require! '../../lib/event-emitter': {EventEmitter}
require! 'prelude-ls': {map, flatten}

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

to-ascii = (.map (.char-code-at 0))

as-ascii-arr = (-> it |> str-to-arr |> to-ascii)

checksum = (arr) ->
    # see "How to calculate checksum of a protocol" section
    a = 0
    for arr
        continue if .. is STX
        a += ..
        break if .. is ETX
    a
        |> to-hexstr
        |> last-two-chars
        |> as-ascii-arr

# checksum tests
_visual = -> it |> map to-hexstr |> (.join ' ')
y = as-hex "02 30 30 37 30 30 34 31 34 03 39 33"
ch = y |> checksum |> _visual
expected = "39 33"
if ch isnt expected => throw "Checksum does not calculated correctly: expected: '#{expected}', got: #{ch}"

y = as-hex "02 30 30 35 31 30 30 38 31 30 31 03 66 33"
ch = y |> checksum |> _visual
expected = "66 33"
if ch isnt expected => throw "Checksum does not calculated correctly: expected: '#{expected}', got: #{ch}"

# See "Command list" in the datasheet
COMMANDS =
    read: "51"
    write: "61"
    force-on: "70"
    force-off: "71"

STATUS_CODES =
    "00": {+ok, desc: "OK"}
    "10": {-ok, desc: "Ascii code error"}
    "11": {-ok, desc: "Checksum error"}
    "12": {-ok, desc: "Command undefined"}
    "14": {-ok, desc: "Stop, parity, frame error or overrun"}
    "28": {-ok, desc: "Address out of range"}

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

for k, v of COMMANDS
    COMMANDS[k] = v |> zero-pad(2) |> as-ascii-arr


class VigorComm extends EventEmitter
    (opts) ->
        super!
        @transport = opts.transport

        @station-number = opts.station-number |> to-hexstr _, 2 |> as-ascii-arr
        @recv = []
        bytes-after-etx = 2 # according to datasheet

        @transport.on \data, (data) ~>
            for data
                @recv.push ..
            console.log "recv: ", @recv

    data-read-raw: (start_address, bytes) ->
        bytes_hexstr = self.to_hexstr(bytes, 2)
        st_addr_hexstr = self.to_hexstr(start_address, 4)
        telegram_data = self.node_address + self.sdr.code_str + st_addr_hexstr + bytes_hexstr
        telegram = self.make_command(telegram_data)
        return self.exec_command(telegram, 4, self.sdr)

    make-telegram: (cmd, start-addr, length) ->
        # format: STX + STATION_NUM + COMMAND + START_ADDR + LENGTH + ETX + CHECKSUM
        START_ADDR = start-addr
            |> to-hexstr _, 4
            |> as-ascii-arr
        LENGTH = length
            |> to-hexstr _, 2
            |> as-ascii-arr
        _telegram = flatten [STX, @station-number, COMMANDS[cmd], START_ADDR, LENGTH, ETX]
        return flatten _telegram ++ checksum(_telegram)

    read: ->
        telegram = @make-telegram "read", (START_ADDRESS.m + 1), 1
        console.log "full telegram:", telegram.map((.to-string 16)).map(zero-pad(2)).join('')
        <~ @transport.once \connect
        @transport.write telegram

ser = new SerialPortTransport do
    port: '/dev/ttyUSB0'
    baudrate: 19200
    dataBits: 7
    parity: 'even'
    stopBits: 1
    split-at: null

v = new VigorComm do
    transport: ser
    station-number: 0

v.read!

/* Handle format:

handle =
    name: 'red'
    gpio: 0
    out: yes

*/
export class VigorDriver extends DriverAbstract
    ->
        super!

    init-handle: (handle, emit) ->
        if handle.out
            # this is an output
            console.log "#{handle.name} is initialized as output"
            @io[handle.name] = new Gpio handle.gpio, \out
        else
            console.log "#{handle.name} is initialized as input"
            @io[handle.name] = new Gpio handle.gpio, 'in', 'both'
                ..watch emit

    write: (handle, value, respond) ->
        # we got a write request to the target
        #console.log "we got ", value, "to write as ", handle
        @io[handle.name].write (if value => 1 else 0), respond

    read: (handle, respond) ->
        # we are requested to read the handle value from the target
        #console.log "do something to read the handle:", handle
        @io[handle.name].read respond

    start: ->
        @connected = yes

    stop: ->
        @connected = no


if require.main is module
    null
