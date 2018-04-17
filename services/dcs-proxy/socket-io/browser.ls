require! '../../../lib/sleep': {sleep}
require! 'dcs/transports/socket-io': {SocketIOTransport}
require! '../protocol-actor/client': {ProxyClient}

export class DcsSocketIOBrowser extends ProxyClient
    (opts) ->
        addr = opts.address
        path = "#{opts.path or '/'}socket.io"
        #@log.log "Connecting to #{addr} path: #{path}"
        socket = io.connect addr, path: path
        transport = new SocketIOTransport socket

        super transport, do
            name: \SocketIOBrowser
            forget-password: yes

        @on \connect, ~>
            @log.log "Info: Connected to server with id: ", socket.io.engine.id

        @on \disconnect, ~>
            @log.log "Info: Disconnected."

        # try public login
        auto = sleep 2000ms, ~>
            @log.log "Not logged-in in 2 seconds, triggering public login"
            @login {user: 'public', password: 'public'}

        @on \logged-in, ~>
            @log.log "Seems logged in, cancelling public login"
            try clear-timeout auto

        @on \logged-out, ~>
            @log.log "Logged out, perform a public login in 1 second"
            <~ sleep 1000ms
            @log.log "...logging in..."
            @login {user: 'public', password: 'public'}
