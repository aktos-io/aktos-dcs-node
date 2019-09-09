require! '../driver-abstract': {DriverAbstract}
require! '../../': {sleep}
require! '../../transports/serial-port': {SerialPortTransport}
require! './vigor-comm': {VigorComm, serial-settings}
require! '../../lib/memory-map': {BlockRead}


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
            ..type = "bool"
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
