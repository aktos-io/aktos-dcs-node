require! '../driver-abstract': {DriverAbstract}
require! '../../': {sleep}
require! '../../transports/serial-port': {SerialPortTransport}
require! './vigor-comm': {VigorComm, serial-settings}
require! "./lib": {split-bits}

parse-io-addr = (full-name) ->
    # "x5.3" => {prefix: "x", byte: 5, bit: 3}
    [prefix, byte, bit-sep, bit] = full-name.split /(\d+)/
    parsed =
        prefix: prefix
        byte: parse-int(byte),
        bit: if bit-sep => parse-int bit else null
        bool: if bit-sep => yes else no
    return parsed

make-io-addr = (prefix, byte, bit) ->
    # x, 3, 5 => "x3.5"
    # x, 4 => "x4"
    "#{prefix}#{byte}#{if bit then ".#{bit}"}"

class BlockRead
    (opts) ->
        @prefix = opts.prefix
        @from = opts.from
        @count = opts.count
        @bits0 = [] # previous states
        @bits = []
        @handlers = {}

    read-params: ~
        -> [@prefix, @from, @count]

    add-handler: (name, handler) ->
        if name of @handlers
            console.error "#{name} is already registered, not registering again."
        else
            @handlers[name] = handler

    distribute: (arr) !->
        @bits.length = 0
        for arr
            @bits.push split-bits ..

        for i of @bits
            for j of @bits[i]
                if @bits[i][j] isnt @bits0[i]?[j]
                    #console.log "bit #{i}#{j} is changed to: ", @bits[i][j]
                    @handlers[make-io-addr @prefix, i, j]? @bits[i][j]

        @bits0 = JSON.parse JSON.stringify @bits


export class VigorDriver extends DriverAbstract
    (opts={}) ->
        super!
        ser = new SerialPortTransport (serial-settings <<< (opts.serial or {}))
            ..on \connect, ~>
                @connected = yes
            ..on \disconnect, ~>
                @connected = no

        plc-settings =
            station-number: opts.plc?station-number or 0
            transport: ser
        @vigor = new VigorComm plc-settings

        @io = new BlockRead do
            prefix: "x"
            from: 0
            count: 8

        <~ sleep 1000ms
        <~ :lo(op) ~>
            err, res <~ @vigor.read ...@io.read-params
            unless err
                @io.distribute res
            <~ sleep 100ms
            lo(op)

    init-handle: (handle, emit) ->
        @io.add-handler handle.addr, emit

    write: (handle, value, respond) ->
        # we got a write request to the target
        #console.log "we got ", value, "to write as ", handle
        if handle.type is \bool
            @vigor.bit-write handle.addr, value, respond
        else
            ...

    read: (handle, respond) ->
        # we are requested to read the handle value from the target
        #console.log "do something to read the handle:", handle
        if handle.type is \bool
            @vigor.bit-read handle.addr, respond
        else
            ...

# example
if require.main is module
    _handles =
        myout:
            addr: "y1.1"
            out: yes
        in1:
            addr: "x0.1"
        in2:
            addr: "x0.2"

    handles = {}
    for name, params of _handles
        handle = params
            ..name = name
            ..type = if (parse-io-addr params.addr .bool) => \bool else \integer
        handles[name] = handle

    console.log "Example usage:"
    driver = new VigorDriver
    for let name, handle of handles
        # format: {name, addr, out?}
        driver.init-handle handle, (value) ->
            console.log "handle state for #{name}: ", value

    <~ driver.once \connect
    driver.write handles.myout, true, (err) ->
        console.log "write result of #{handle.name}:", (if err => "failed" else "succeeded")
    <~ sleep 1000ms
    driver.write handles.myout, false, (err) ->
        console.log "write result of #{handle.name}:", (if err => "failed" else "succeeded")
