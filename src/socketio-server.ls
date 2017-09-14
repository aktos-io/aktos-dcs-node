require! './actor': {Actor}
require! './proxy-authority': {ProxyAuthority}
require! 'socket.io': socketio
require! './socketio-helpers': {Wrapper}

export class SocketIOServer extends Actor
    (@http, opts={}) ->
        super 'SocketIO Server'
        @io = socketio @http
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

    action: ->
        @log.log "SocketIO server started..."
