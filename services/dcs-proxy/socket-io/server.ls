require! 'socket.io': socketio
require! '../deps': {Logger}
require! 'dcs/transports/socket-io': {SocketIOTransport}
require! '../protocol-actor/handler': {ProxyHandler}


export class DcsSocketIOServer
    (@http, opts={}) ->
        io = socketio @http
        @log = new Logger \SocketIOServer
        count = 0
        seq = 0

        io.on 'connection', (socket) ~>
            transport = new SocketIOTransport socket

            # launch a new handler
            handler = new ProxyHandler transport, do
                name: "s.io-#{seq++}"
                db: opts.db

            handler.on \kill, (reason) ~>
                count--
                @log.log "Total online users: #{count}"

            # track online users
            count++
            @log.log "Total online users: #{count}"

        @log.log "SocketIO server is started..."
