require! 'net'
require! './actor': {Actor}
require! 'colors': {yellow, green, red, blue, bg-green, bg-red}
require! 'aea': {sleep, pack, hex, ip-to-hex}
require! 'prelude-ls': {drop, reverse}
require! './proxy-client': {ProxyClient}


export class TCPProxyClient extends Actor
    (opts={}) ->
        super opts.name or \TCPProxyClient
        @opts <<< opts 
        @client = null
        @client-connected = no
        @client-actor = null
        @port = if @opts.port => that else 5523

        @client = new net.Socket!
        @log.log "Starting..."

        proxy = new ProxyClient @client, do
            name: (@opts.name or 'client') + '-conn'
            creator: this

        proxy.on \kill, (reason) ~>
            @log.log "Creator says proxy actor (client) (#{proxy.id}) just died!"

        connecting = no
        connected = no

        proxy.on \connected, ~>
            connected := yes
            connecting := no
            @log.log "TCPProxyClient is running."

        do connect = ~>
            return if connected
            return if connecting
            connecting := yes

            @client.connect @port, '127.0.0.1'

        do
            <- :lo(op) ->
                <- sleep 1000000
                lo(op)

        proxy.on \needReconnect, (reason) ~>
            @log.log "proxy actor requested reconnection. Reconnecting in 1000ms."
            @client.destroy!
            @client.unref!
            connected := no
            connecting := no
            <~ sleep 1000ms
            @log.log "reconnecting..."
            connect!

        @client-proxy = proxy

    login: (credentials, callback) ->
        unless callback
            callback = (err, res) ~>
                return @log.err bg-red "Something went wrong while login: ", pack(err) if err
                return @log.err bg-red "Wrong credentials?" if res.auth?error
                @log.log bg-green "Logged in into the DCS network."

        @client-proxy.login credentials, callback
