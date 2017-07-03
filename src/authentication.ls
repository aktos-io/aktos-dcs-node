require! './core': {ActorBase}
require! './signal': {Signal}
require! 'aea': {sleep}
require! './authorization':{get-all-permissions}
require! 'uuid4'
require! 'colors': {red, green, yellow}
require! 'aea/debug-log': {logger}
require! './auth-helpers': {hash-passwd}





export class AuthRequest extends ActorBase
    @i = 0
    ->
        super "AuthRequest.#{@@i++}"
        @login-signal = new Signal!
        @logout-signal = new Signal!

    inbox: (msg) ->
        if \auth of msg
            #@log.log "Auth actor got authentication message", msg
            if \session of msg.auth
                @login-signal.go msg
            else if \logout of msg.auth
                if msg.auth.logout is \ok
                    @logout-signal.go msg

    login: (credentials, callback) ->
        # credentials might be one of the following:
        # 1. {username: ..., password: ...}
        # 2. {token: ...}

        credentials.password = hash-passwd credentials.password
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

    send: (msg) -> @send-raw @msg-template msg <<< sender: @id

    send-with-token: (msg) ->
        @send-raw msg <<< token: @token

    send-raw: (msg) ->
        ...

can-write = (token, topic) ->
    try
        if AuthHandler.session-cache[token].permissions.rw
            return if topic in that => yes else no
    catch
        no

can-read = (token, topic) ->
    try
        if AuthHandler.session-cache[token].permissions.ro
            return if topic in that => yes else no
    catch
        no


export class AuthHandler extends ActorBase
    @login-delay = 10ms
    @i = 0
    (@db) ->
        super "AuthHandler.#{@@i++}"
        @session = {}
        throw "No db supplied!" unless @db

    process: (msg) ->
        @log.log "Processing authentication message"
        if \username of msg.auth
            # login request
            err, doc <~ @db.get-user msg.auth.username
            if err
                @log.err "user is not found: ", err
            else
                if doc.passwd-hash is msg.auth.password
                    @log.log "#{msg.auth.username} logged in."
                    err, permissions-db <~ @db.get-permissions
                    return @log.log "error while getting permissions" if err
                    token = uuid4!

                    @session =
                        token: token
                        user: msg.auth.username
                        date: Date.now!
                        permissions: get-all-permissions doc.roles, permissions-db
                        opening-scene: doc.opening-scene

                    @log.log "(...sending with #{@@login-delay}ms delay)"
                    <~ sleep @@login-delay
                    @send auth: session: @session
                else
                    @log.err "wrong password", doc, msg.auth.password
                    @send auth: session: \wrong

        else if \logout of msg.auth
            # session end request
            unless @session.token
                @log.log "No user found with the following token: #{msg.token} "
                return
            else
                @log.log "logging out for #{@session.user}"
                @session = {}
                @send auth: logout: \ok

        else if \token of msg.auth
            if @session.token is msg.auth.token
                # this is a valid session token
                @log.log "(...sending with #{@@login-delay}ms delay)"
                <~ sleep @@login-delay
                @send auth: session: @session
            else
                # means "you are not already logged in, do a logout action over there"
                @send auth: logout: 'yes'
        else
            @log.err yellow "Can not determine which auth request this was: ", msg

    send: (msg) -> @send-raw @msg-template msg <<< sender: @id

    send-raw: (msg) ->
        ...
