require! 'socket.io': socketio
require! './helpers': {Wrapper}
require! 'aea': {Logger}
require! '../../src/actor': {Actor}
require! './helpers': {Wrapper}
require! '../../proxy/authority': {ProxyAuthority}


export class SocketIOServer
    (@http, opts={}) ->
        @io = socketio @http
        @log = new Logger \SocketIOServer
        @connected-user-count = 0
        @handler-counter = 0

        @io.on 'connection', (socket) ~>
            # track online users
            @connected-user-count++

            # launch a new handler
            proxy = new ProxyAuthority (new Wrapper socket), do
                name: "socketio-#{@connected-user-count}"
                creator: this
                db: opts.db

            proxy.on \kill, (reason) ~>
                @log.log "Creator says proxy actor (authority) (#{proxy.id}) just died!"
                @connected-user-count++


        @log.log "SocketIO server started..."
