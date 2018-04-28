require! '../../../lib/sleep': {sleep}
require! 'dcs/transports/socket-io': {SocketIOTransport}
require! '../protocol-actor/client': {ProxyClient}


export class DcsSocketIOBrowser extends ProxyClient
    (opts) ->
        '''
        params:

            opts.db:  is a permanent data storage with
                `get`, `set` and `del` methods.
        '''
        addr = opts.address
        path = "#{opts.path or '/'}socket.io"
        #@log.log "Connecting to #{addr} path: #{path}"
        socket = io.connect addr, path: path
        transport = new SocketIOTransport socket
        super transport, do
            name: \SocketIOBrowser
            forget-password: yes

        db = opts.db
        if db.get \token
            # there is a token currently, use token to sign in
            @log.log "logging in with token: ", that
            err, res <~ @login {token: that}
            @log.info "login with token:", err, res
        else
            # no token found, try a public login
            @log.log "performing a public login"
            err, res <~ @login {user: 'public', password: 'public'}
            #####debugger
            if err
                @log.warn "Public login is failed: ", err

        @on \connect, ~>
            @log.info "Connected to server with id: ", socket.io.engine.id

        @on \disconnect, ~>
            @log.info "Disconnected."

        @on-topic \app.dcs.do-login, (msg) ~>
            err, res <~ @login msg.payload
            if res?.auth?.session?.token
                @log.info "Logged in, got token: ", that
                db.set \token, that
            @send-response msg, {err, res}

        @on \logged-in, (session, clear-password) ~>
            @log.info "clearing the plaintext password."
            clear-password!

        @on-topic \app.dcs.do-logout, (msg) ~>
            @log.info "Logging out."
            err, res <~ @logout
            @send-response msg, {err, res: res.auth}

        public-login-allowed = yes
        @on \logged-out, (reason) ~>
            if (reason?.code is \GRACEFUL) and public-login-allowed
                @log.log "Logged out, perform a public login in 100ms"
                <~ sleep 100ms
                @log.log "...logging in..."
                err, res <~ @login {user: 'public', password: 'public'}
                console.log "automatic login: err, res: ", err, res
