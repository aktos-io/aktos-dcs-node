require! './core': {ActorBase}
require! './signal': {Signal}
require! 'aea': {sleep}
require! './aea-auth':{hash-passwd, get-all-permissions}
require! 'uuid4'
require! 'colors': {red, green, yellow}

export class AuthRequest extends ActorBase
    @instance = null
    ->
        return @@instance if @@instance
        @@instance = this
        super \AuthRequest

        @login-signal = new Signal!
        @logout-signal = new Signal!
        @setup-ok = no

    setup: (@settings) ->
        unless @settings.transport
            throw "transport should be defined!"
        unless @settings.receive-interface
            throw "receive-interface should be defined!"
        unless @settings.send-interface
            throw "send-interface should be defined!"

        @settings.transport.on @settings.receive-interface, (msg) ~>
            if \auth of msg
                #@log.log "Auth actor got authentication message", msg
                if \session of msg.auth
                    @login-signal.go msg
                else if \logout of msg.auth
                    if msg.auth.logout is \ok
                        @logout-signal.go msg

        @send-raw = @settings.transport[@settings.send-interface]
            .bind @settings.transport

        @setup-ok = yes

    login: (credentials, callback) ->
        # credentials might be one of the following:
        # 1. {username: ..., password: ...}
        # 2. {token: ...}
        unless @setup-ok
            @log.err "Setup first!"
            throw

        @log.log "Trying to authenticate with the following credentials: ", credentials
        @send auth: credentials
        # FIXME: why do we need to clear the signal?
        @login-signal.clear!
        reason, res <~ @login-signal.wait 3000ms

        err = if reason is \timeout
            {reason: \timeout}
        else
            no

        # store token in order to use in every message
        @token = try res.auth.session.token
        callback err, res


    logout: (callback) ->
        @send auth: logout: yes
        reason, msg <~ @logout-signal.wait 3000ms
        err = if reason is \timeout
            {reason: 'timeout'}
        else
            no

        if not err and msg.auth.logout is \ok
            @log.log "clearing token storage"
            @token = null

        callback err, msg

    send: (msg) -> @send-raw @msg-template msg <<< sender: @actor-id


login-delay = 10ms

export class AuthHandler extends ActorBase
    @session-cache = {}
    @instance = null
    ->
        return @@instance if @@instance
        @@instance = this

        super \AuthHandler
        @setup-ok = no

    setup: (@settings) ->
        @db = @settings.db
        if @db
            @setup-ok = yes

    process: (msg, send-back) ->
        unless @setup-ok
            @log.log red "Not set up, dropping auth message silently."
            return

        @log.log "Processing authentication message"
        if msg.auth
            if \username of msg.auth
                # login request
                err, doc <~ @db.get-user msg.auth.username
                if err
                    @log.err "user is not found: ", err
                else
                    if doc.passwd-hash is hash-passwd msg.auth.password
                        @log.log "#{msg.auth.username} logged in."
                        err, permissions-db <~ @db.get-permissions
                        return @log.log "error while getting permissions" if err
                        token = uuid4!

                        @@session-cache[token] =
                            token: token
                            user: msg.auth.username
                            date: Date.now!
                            permissions: get-all-permissions doc.roles, permissions-db
                            opening-scene: doc.opening-scene

                        @log.log "(...sending with #{login-delay}ms delay)"
                        <~ sleep login-delay
                        send-back @msg-template! <<<< do
                            sender: @actor-id
                            auth: session: @@session-cache[token]

                        # will be used for checking read permissions
                        @token = token
                    else
                        @log.err "wrong password", doc, msg.auth.password
                        send-back @msg-template! <<<< do
                            sender: @actor-id
                            auth: session: \wrong

            else if \logout of msg.auth
                # session end request
                unless @@session-cache[msg.token]
                    @log.log "No user found with the following token: #{msg.token} "
                    return
                else
                    @log.log "logging out for #{@@session-cache[msg.token].user}"
                    delete @@session-cache[msg.token]
                    sender @msg-template <<< auth: logout: \ok

            else if \token of msg.auth
                response = @msg-template!
                if @@session-cache[msg.auth.token]
                    # this is a valid session token
                    @log.log "(...sending with #{login-delay}ms delay)"
                    <~ sleep login-delay
                    response <<<< auth: session: that
                    send-back response
                else
                    # means "you are not already logged in, do a logout action over there"
                    response <<<< auth: logout: 'yes'
                    send-back response
            else
                @log.err yellow "Can not determine which auth request this was: ", msg
