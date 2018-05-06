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
            @log.info "Connected to server..."

        @on \disconnect, ~>
            @log.info "Disconnected."

        @on-topic \app.dcs.connect, (msg) ~>
            @log.info "Tcp Client is logged in into the DCS network."

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
