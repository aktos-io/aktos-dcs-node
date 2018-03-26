require! 'net'
require! 'colors': {yellow, green, red, blue, bg-green}
require! '../protocol-actor/handler':{ProxyHandler}
require! '../deps': {Logger}
require! 'dcs/transports/tcp': {TcpHandlerTransport}


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

            handler = new ProxyHandler transport, do
                name: "tcp-#{seq++}"
                db: opts.db

            handler.on \kill, (reason) ~>
                count--
                @log.log "Total online users: #{count}"

            # track online users
            count++
            @log.log "Total online users: #{count}"

        server
            ..on \error, (e) ~>
                if e.code is 'EADDRINUSE'
                    @log.warn "Address in use, giving up."
                    server.close!

            ..listen @port, ~>
                @log.log "TCP DCS Server started on port #{bg-green @port}."
