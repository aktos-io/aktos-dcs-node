require! 'net'
require! 'colors': {yellow, green, red, blue, bg-green}
require! '../protocol-actor/handler':{ProxyHandler}
require! '../deps': {Logger}
require! 'dcs/transports/tcp/handler': {TcpHandlerTransport}


export class DcsTcpServer
    (opts={}) ->
        """
        opts:
            db: auth-db object
            port: dcs port
        """
        @port = opts.port or 5523
        @log = new Logger \TcpDcsServer

        count = 0
        seq = 0
        server = net.create-server (socket) ~>
            transport = new TcpHandlerTransport socket
            count++

            handler = new ProxyHandler transport, do
                name: "handler-#{seq++} (\##{count})"
                db: opts.db

            handler.on \kill, (reason) ->
                @log.log "ProxyHandler is just died!"
                count--

        server
            ..on \error, (e) ~>
                if e.code is 'EADDRINUSE'
                    @log.warn "Address in use, giving up."
                    server.close!

            ..listen @port, ~>
                @log.log "TCP DCS Server started on port #{bg-green @port}."
