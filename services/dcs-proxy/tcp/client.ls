require! '../protocol-actor/client': {ProxyClient}
require! 'dcs/transports/tcp': {TcpTransport}

export class DcsTcpClient extends ProxyClient
    (@opts={}) ->
        @opts.port or throw "DcsTcpClient: Port is required."
        transport = new TcpTransport do
            host: @opts.host or \127.0.0.1
            port: @opts.port

        super transport, do
            name: \TcpDcsClient
            forget-password: no

        @on \connect, ~>
            @log.log "Info: Connected to server..."

        @on \disconnect, ~>
            @log.log "Info: Disconnected."

        # A Tcp client should always try re-login (even though credentials are incorrect)
        /*
            unless error
                #@log.log "seems logged in: session:", res.auth.session
                @trigger \logged-in, res.auth.session
            else
                unless error is "EMPTY_CREDENTIALS"
                    @log.info "ProxyClient will try to reconnect."
                    if @connected
                        <~ sleep 3000ms
                        @trigger \_login, {forget-password: @opts.forget-password}
        */
