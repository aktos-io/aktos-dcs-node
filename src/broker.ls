require! 'net'
require! './actor': {Actor}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {drop, reverse, split, flatten, split-at}
require! 'colors': {yellow, green, red}

hex = (n) ->
    n.to-string 16 .to-upper-case!

ip-to-hex = (ip) ->
    i = 0
    result = 0
    for part in reverse ip.split '.'
        result += part * (256**i++)

    hex result

unpack-telegrams = (data) ->
    if typeof! data isnt \String
        return []

    boundary = data.index-of '}{'
    if boundary > -1
        [_first, _rest] = split-at (boundary + 1), data
    else
        _first = data
        _rest = null

    _first-telegram = try
        unpack _first
    catch
        console.log "data can not be unpacked: ", _first
        console.log e

    packets = flatten [_first-telegram, unpack-telegrams _rest]
    return packets



class BrokerHandler extends Actor
    (@socket) ->
        """
        Broker handler(s) are just simple forwarders between a network node
        and the ActorManager.

        This handler simply forwards from `network` interface to `local`
        interface and vice versa.
        """
        @socket.name = "H#{ip-to-hex (drop 7, socket.remoteAddress)}:#{hex socket.remotePort}"
        super @socket.name

        @log.sections ++= [
            'debug-kill'
            #'debug-redirect'
        ]

        @subscribe '**'

        @on do
            receive: (msg) ~>
                @network-send msg
            kill: ~>
                @socket.end!
                @socket.destroy 'KILLED'

        # socket actions
        @socket.on \error, (e) ~>
            if e.code in <[ EPIPE ECONNREFUSED ECONNRESET ETIMEDOUT ]>
                @log.err "Socket Error: ", e.code
            else
                @log.err "Socket Error: ", e

            @log.log "This actor should be killed!"
            @kill!

        @socket.on \data, (data) ~>
            for telegram in unpack-telegrams data.to-string!
                @network-receive telegram

    action: ->
        @log.log "BrokerHandler is launched."

    network-receive: (msg) ->
        @log.section \debug-redirect,
            "redirecting msg from 'network' interface to 'local' interface \
            type: #{if 'update' of msg then 'update' else 'data'}"

        @send-enveloped msg

    network-send: (msg) ->
        try
            @log.section \debug-redirect,
                "redirecting msg from 'local' interface to 'network' interface,\
                type: #{if 'update' of msg then 'update' else 'data'}"
            @socket.write pack msg
        catch
            @log.warn "TODO: FIXME: Actor should not kill itself on first error."
            @kill!

export class Broker extends Actor
    (@opts={}) ->
        super \Broker
        @server = null
        @client = null
        @client-connected = no
        @client-actor = null

        @port = if @opts.port => that else 5523
        @mgr.db = that if @opts.db

        @server-retry-period = 2000ms

        @server-mode-allowed = if @mgr.db => yes else no

    action: ->
        @_start!

    _start: ->
        if @server-mode-allowed
            @server = net.create-server (socket) ->
                new BrokerHandler socket

            @server.on \error, (e) ~>
                if e.code is 'EADDRINUSE'
                    @log.section \debug, "Address in use, retrying in #{@server-retry-period}ms"
                    @run-client!
                    <~ sleep @server-retry-period
                    @server.close!
                    @_start!

            @server.listen @port, ~>
                @log.log "Broker started in #{green "server mode"} on port #{@port}."

        else
            @log.log (yellow "INFO : "), "Server mode is not allowed."
            @run-client!

    _authenticate: (callback) ->
        @log.log "Simulating authentication..."
        <~ sleep 2000ms
        @log.log "Simulating authentication done..."
        callback!

    run-client: ->
        if @server?.listening
            @log.log "Client mode can not be run while server mode has been started already."
            return

        if @client-connected
            @log.section \debug, yellow "Already connected"
            return

        @client = new net.Socket!
        @client.on \error, (e) ~>
            @log.err "Client mode had error: ", e.code
            if @server.listening
                @log.log "not restarting in client mode, since server is running"
                return
            if e.code in <[ EPIPE ECONNREFUSED ECONNRESET ETIMEDOUT ]>
                # connection has an error, try to reconnect.
                @log.log yellow "trying to restart client mode in #{@server-retry-period}ms..."
                @client-actor.kill!
                <~ sleep @server-retry-period
                @client-connected = no
                @run-client!

        @client.connect @port, '127.0.0.1', ~>
            @log.log "Broker is started in #{yellow "client mode"}."
            @client-connected = yes
            <~ @_authenticate
            @log.log "Launching BrokerHandler for client mode..."
            @client-actor = new BrokerHandler @client
