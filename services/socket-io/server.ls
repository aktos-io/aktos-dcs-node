require! 'socket.io': socketio
require! '../../lib': {Logger}
require! '../../transports/socket-io': {SocketIOTransport}
require! '../../protocol-actors/proxy/handler': {ProxyHandler}


export class SocketIOServer
    (@http, opts={}) ->
        io = socketio @http
        @log = new Logger \SocketIOServer
        count = 0
        seq = 0

        io.on 'connection', (socket) ~>
            transport = new SocketIOTransport socket

            # track online users by handler name
            count++

            # launch a new handler
            handler = new ProxyHandler transport, do
                name: "socketio-#{seq++} (\##{count})"
                db: opts.db

            handler.on \kill, (reason) ->
                @log.log "ProxyHandler is just died!"
                count--

        @log.log "SocketIO server is started..."
