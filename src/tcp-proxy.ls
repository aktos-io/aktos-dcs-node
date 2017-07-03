require! 'net'
require! './actor': {Actor}
require! 'colors': {yellow, green, red, blue}
require! 'aea': {sleep}
require! 'prelude-ls': {drop, reverse}
require! './proxy-actor':{ProxyAuthority, ProxyClient}

hex = (n) -> n.to-string 16 .to-upper-case!

ip-to-hex = (ip) ->
    i = 0
    result = 0
    for part in reverse ip.split '.'
        result += part * (256**i++)

    hex result


export class TCPProxy extends Actor
    (@opts={}) ->
        super \TCPProxy
        @server = null
        @client = null
        @client-connected = no
        @client-actor = null

        @port = if @opts.port => that else 5523
        @server-retry-period = 2000ms
        @server-mode-allowed = if @opts.server-mode => yes else no

    action: ->
        @_start!

    _start: ->
        if @server-mode-allowed
            @server = net.create-server (socket) ~>
                name = "H#{ip-to-hex (drop 7, socket.remoteAddress)}:#{hex socket.remotePort}"

                proxy = new ProxyAuthority socket, do
                    name: name
                    creator: this
                    db: @opts.db 

                proxy.on \kill, (reason) ~>
                    @log.log "Creator says proxy actor (authority) (#{proxy.id}) just died!"

            @server.on \error, (e) ~>
                if e.code is 'EADDRINUSE'
                    @log.warn "Address in use, retrying in #{@server-retry-period}ms"
                    @run-client!
                    <~ sleep @server-retry-period
                    @server.close!
                    @_start!

            @server.listen @port, ~>
                @log.log "Broker started in #{green "server mode"} on port #{@port}."

        else
            @log.log (yellow "INFO : "), "Server mode is not allowed."
            @run-client!

    run-client: ->
        if @server?.listening
            @log.log "Client mode can not be run while server mode has been started already."
            return

        @client = new net.Socket!

        @log.log "Launching BrokerHandler for client mode..."
        proxy = new ProxyClient @client, do
            name: \client-proxy
            creator: this

        proxy.on \kill, (reason) ~>
            @log.log "Creator says proxy actor (client) (#{proxy.id}) just died!"


        connecting = no
        connected = no

        @client.on \connect, ~>
            connected := yes
            connecting := no
            @log.log "Broker is started in", yellow "client mode"
            proxy.trigger \connected

        do connect = ~>
            return if connected
            return if connecting
            connecting := yes

            @client.connect @port, '127.0.0.1'

        do
            <- :lo(op) ->
                <- sleep 1000000
                lo(op)

        proxy.on \reconnect, (reason) ~>
            @log.log "proxy actor requested reconnection. Reconnecting in 1000ms."
            @client.destroy!
            @client.unref!
            connected := no
            connecting := no
            <~ sleep 1000ms
            @log.log "reconnecting..."
            connect!
