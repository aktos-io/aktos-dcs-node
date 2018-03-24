require! 'colors': {yellow, green, red, blue, bg-green, bg-red}
require! '../../lib': {sleep, pack, hex, ip-to-hex, Logger, EventEmitter}
require! 'prelude-ls': {drop, reverse}
require! '../../proxy/client': {ProxyClient}
require! '../../transports/tcp': {TcpTransport}

export class TcpDcsClient extends EventEmitter
    (@opts={}) ->
        super!
        @log = new Logger \TcpDcsClient
        @log.log "Starting..."
        @transport = new TcpTransport do
            host: @opts.host
            port: @opts.port

        # refire transport events
        @transport
            ..on \disconnect, ~> @trigger \disconnect, ...arguments
            ..on \connect, ~> @trigger \connect, ...arguments

        @proxy = new ProxyClient @transport, do
            name: (@opts.name or 'client') + '-connector'
            creator: this

        @proxy.on \logged-in, ~>
            @trigger \logged-in, ...arguments

    login: (credentials, callback) ->
        unless callback
            callback = (err, res) ~>
                if err
                    @log.err bg-red "Something went wrong while login: ", pack(err)
                else if res.auth?error
                    @log.err bg-red "Wrong credentials?"
                else
                    @log.log bg-green "Logged in into the DCS network."

        @proxy.login credentials, callback
