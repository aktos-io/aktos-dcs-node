require! '../../../lib/sleep': {sleep}
require! '../../../transports/socket-io': {SocketIOTransport}
require! '../protocol-actor/client': {ProxyClient}
require! 'socket.io-client': io

class Storage
    ->
        console.warn "DEVELOPER MODE: Using in-memory storage for DcsSocketIOBrowser"
        @memory = {}

    set: (key, value) ->
        @memory[key] = value

    del: (key) ->
        delete @memory[key]

    get: (key) ->
        @memory[key]


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

        db = opts.db or (new Storage)
        if db.get \token
            #### there is a token currently, use token to sign in
            #@log.log "logging in with token: ", that
            err, res <~ @login {token: that}
            #@log.info "login with token:", err, res
        else
            #### no token found, try a public login
            #@log.log "performing a public login"
            err, res <~ @login {user: 'public', password: 'public'}
            if err
                @log.warn "Public login is failed: ", err

        @on \connect, ~>
            @log.info "Connected to server with id: ", socket.io.engine.id

        @on \disconnect, ~>
            @log.info "Disconnected."

        @on-topic \app.dcs.do-login, (msg) ~>
            if msg.debug => debugger
            err, res <~ @login msg.data
            if res?.auth?.session?.token
                #@log.info "Logged in, got token: ", that
                db.set \token, that
            #@log.log "responding to app.dcs.do-login message: ", err, res
            @send-response msg, {err, res}

        @on \logged-in, (session, clear-password) ~>
            #@log.info "clearing the plaintext password."
            clear-password!

        @on-topic \app.dcs.do-logout, (msg) ~>
            @log.info "Logging out."
            err, res <~ @logout
            @send-response msg, {err, res: res.auth}

        public-login-allowed = yes
        try-relogin = ~>
            @log.log "This is a logout"
            db.del \token
            if (reason?.code is \GRACEFUL) and public-login-allowed
                @log.log "Logged out, perform a public login in 100ms"
                <~ sleep 100ms
                @log.log "...logging in..."
                err, res <~ @login {user: 'public', password: 'public'}
                console.log "automatic login: err, res: ", err, res

        @on \logged-out, (reason) ~>
            try-relogin reason

        @on \kicked-out, ~>
            try-relogin!
