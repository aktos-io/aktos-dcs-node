require! '../driver-abstract': {DriverAbstract}
require! '../../': {sleep}
require! '../../transports/serial-port': {SerialPortTransport}
require! './vigor-comm': {VigorComm, serial-settings}


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

    init-handle: (handle, emit) ->

    write: (handle, value, respond) ->
        # we got a write request to the target
        #console.log "we got ", value, "to write as ", handle
        if handle.bool
            @vigor.bit-write handle.addr, value, respond
        else
            ...

    read: (handle, respond) ->
        # we are requested to read the handle value from the target
        #console.log "do something to read the handle:", handle
        if handle.bool
            @vigor.bit-read handle.addr, respond
        else
            ...

# example
if require.main is module
    handle =
        name: 'myout'
        addr: "y1"
        bool: yes
        out: yes

    driver = new VigorDriver
    <~ driver.once \connect
    driver.write handle, true, (err) ->
        console.log "write result of #{handle.name}:", err
    driver.read handle, (err, res) ->
        console.log "read result of #{handle.name}: ", err, res
