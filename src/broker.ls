require! 'net'
require! './actor': {Actor}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {drop, reverse}

hex = (n) ->
    n.to-string 16 .to-upper-case!

ip-to-hex = (ip) ->
    i = 0
    result = 0
    for part in reverse ip.split '.'
        result += part * (256**i++)

    hex result


class BrokerHandler extends Actor
    (socket) ->
        """
        Broker handler(s) are just simple forwarders between a network node
        and the ActorManager.

        This handler simply forwards from `network` interface to `local`
        interface and vice versa.
        """
        socket.name = "H#{ip-to-hex (drop 7, socket.remoteAddress)}:#{hex socket.remotePort}"
        super socket.name
        @socket = socket

        @on-receive (msg) ~>
            @network-send msg

        @on-kill ->
            @socket.end!
            @socket.destroy 'KILLED'

        # socket actions
        @socket.on \error, (e) ~>
            @log.err "Socket Error: ", e
            @kill!

        @socket.on \data, (data) ~>
            packet = data.to-string!
            try
                @network-receive unpack packet
            catch
                @log.err "data can not be unpacked: ", packet
                @log.err e

    action: ->
        @log.log "BrokerHandler is connected to remote point. This is: #{@name}"

    network-receive: (msg) ->
        @send_raw msg

    network-send: (data) ->
        try
            @socket.write pack data
        catch
            @log.err "THIS ACTOR SHOULD HAVE BEEN KILLED!!!"
            @kill!

class Broker extends Actor
    ->
        super \Broker
        @server = null
        @client = null
        @client-connected = no
        @client-actor = null

        @port = 5523
        @server-retry-period = 2000ms

    action: ->
        @run-server!

    run-server: ->
        @server = net.create-server (socket) ->
            new BrokerHandler socket

        @server.on \error, (e) ~>
            if e.code is 'EADDRINUSE'
                @log.section \debug, "Address in use, retrying in #{@server-retry-period}ms"
                @run-client!
                <~ sleep @server-retry-period
                @server.close!
                @run-server!

        @server.listen @port, ~>
            @log.log "Broker started in server mode."

    run-client: ->
        if @server.listening
            @log.log "Client mode can not be run while server mode has been started already."
            return

        if @client-connected
            @log.section \debug, "Already connected"
            return

        @client = new net.Socket!
        @client.on \error, (e) ~>
            @log.err "Client mode had error: ", e.code
            if @server.listening
                @log.log "not restarting in client mode, since server is running"
                return
            if e.code in <[ EPIPE ECONNREFUSED ECONNRESET ETIMEDOUT ]>
                # connection has an error, try to reconnect.
                @log.log "trying to restart client mode in #{@server-retry-period}ms..."
                @client-actor.kill!
                <~ sleep @server-retry-period
                @client-connected = no
                @run-client!

        @client.connect @port, '127.0.0.1', ~>
            @log.log "Broker is started in client mode."
            @client-connected = yes

            @log.log "Launching BrokerHandler for client mode..."
            @client-actor = new BrokerHandler @client

new Broker!

class Simulator extends Actor
    ->
        super ...

        @on-receive (msg) ~>
            @log.log "got message: ", msg.payload

    action: ->
        do ~>
            <~ :lo(op) ~>
                msg = "sending test message from #{@name}...."
                @log.log msg
                @send msg, '*' # send broadcast
                <~ sleep 2000ms
                lo(op)



new Simulator \one
new Simulator \two
