require! '../protocol-actor/client': {ProxyClient}
require! '../../../transports/tcp': {TcpTransport}
require! '../deps': {sleep}

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

        @on-topic \app.dcs.connect, (msg) ~>
            @log.info "Tcp Client is logged in into the DCS network."

        # A Tcp client should always try re-login (even though credentials are incorrect)
        @on \disconnect, ~>
            @log.info "Disconnected."
            @log.info "ProxyClient will try to reconnect."
            if @connected
                <~ sleep 3000ms
                @trigger \_login
