require! 'net'
require! 'colors': {yellow, green, red, blue, bg-green, bg-red}
require! '../../lib': {sleep, pack, hex, ip-to-hex, Logger, EventEmitter}
require! 'prelude-ls': {drop, reverse}
require! '../../proxy/client': {ProxyClient}


export class TCPProxyClient extends EventEmitter
    (@opts={}) ->
        super!
        @client = null
        @client-connected = no
        @client-actor = null
        @port = if @opts.port => that else 5523
        @log = new Logger \TCPProxyClient
        @client = new net.Socket!
        @log.log "Starting..."

        @client-proxy = new ProxyClient @client, do
            name: (@opts.name or 'client') + '-conn'
            creator: this

        connecting = no
        connected = no

        do connect = ~>
            return if connected
            return if connecting
            connecting := yes

            @client.connect @port, '127.0.0.1'

        do
            <- :lo(op) ->
                <- sleep 1000000
                lo(op)

        @client-proxy
            ..on \kill, (reason) ~>
                @log.log "Creator says proxy actor (client) (#{@client-proxy.id}) just died!"

            ..on \connected, ~>
                connected := yes
                connecting := no
                @log.log "TCPProxyClient is running."
                @trigger \connect

            ..on \needReconnect, (reason) ~>
                @trigger \disconnect
                @log.log "proxy actor requested reconnection. Reconnecting in 1000ms."
                @client.destroy!
                @client.unref!
                connected := no
                connecting := no
                <~ sleep 1000ms
                @log.log "reconnecting..."
                connect!

            ..on \logged-in, ~>
                @trigger \logged-in

            ..on \error, (...args) ~>
                @trigger \error, ...args



    login: (credentials, callback) ->
        unless callback
            callback = (err, res) ~>
                if err
                    @log.err bg-red "Something went wrong while login: ", pack(err)
                else if res.auth?error
                    @log.err bg-red "Wrong credentials?"
                else
                    @log.log bg-green "Logged in into the DCS network."

        @client-proxy.login credentials, callback
