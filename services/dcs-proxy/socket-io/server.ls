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

            # track online users
            @log.log "Total online users: #{count++}"

            # launch a new handler
            handler = new ProxyHandler transport, do
                name: "socketio-#{seq++}"
                db: opts.db

            handler.on \kill, (reason) ->
                @log.log "ProxyHandler is just died!"
                @log.log "Total online users: #{count--}"

        @log.log "SocketIO server is started..."
