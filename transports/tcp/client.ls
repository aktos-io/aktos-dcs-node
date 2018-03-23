require! 'node-net-reconnect': Reconnect
require! 'net'

require! 'colors': {yellow, green, red, blue, bg-green, bg-red}
require! '../../lib': {sleep, pack, hex, ip-to-hex, Logger, EventEmitter}
require! 'prelude-ls': {drop, reverse}
require! 'net-keepalive': NetKeepAlive


export class TcpTransport extends EventEmitter
    (opts={}) ->
        super!
        @opts =
            host: opts.host or "localhost"
            port: opts.port or 5523
            retry-always: yes

        @log = new Logger \TCP_Transport

        @socket = new net.Socket!
        Reconnect.apply @socket, @opts
        @connected = no
        @socket
            ..setKeepAlive yes, 1000ms
            ..setTimeout 1000ms

            ..on \connect, ~>
                NetKeepAlive.setKeepAliveInterval @socket, 1000ms
                NetKeepAlive.setKeepAliveProbes @socket, 1
                #@log.log "Connected. Try to unplug the connection"
                @trigger \connect
                @connected = yes

            ..on \close, ~>
                if @connected
                    @connected = no
                    #@log.log "Connection is closed."
                    @trigger \disconnect

            ..on \data, (data) ~>
                #@log.log "Received: ", data
                @trigger \data, data

        # maybe start manually?
        @start!

    start: ->
        #@log.log "Starting connection"
        @socket.connect @opts

    write: (data) ->
        @socket.write data

/*
console.log "-------------------------------------"
t = new TcpTransport {host: \localhost, port: 1234}
i = 0
<~ :lo(op) ~>
    t.write "written some data... i: #{i++}"
    <~ sleep 1000ms
    lo(op)
console.log "end of test "
*/
