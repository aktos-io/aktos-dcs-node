require! './core': {ActorBase}
require! './signal': {Signal}
require! 'aea': {sleep, logger}
require! './authorization':{get-all-permissions}
require! 'uuid4'
require! 'colors': {red, green, yellow, bg-red, bg-yellow}
require! 'aea/debug-log': {logger}
require! './auth-helpers': {hash-passwd}
require! './topic-match': {topic-match}

class SessionCache
    @cache = {}
    @instance = null
    ->
        return @@instance if @@instance
        @@instance = this
        @log = new logger \SessionCache
        @log.log green "SessionCache is initialized"

    add: (session) ->
        @log.log green "Adding session for #{session.user}", (yellow session.token)
        @@cache[session.token] = session

    get: (token) ->
        @@cache[token]

    drop: (token) ->
        @log.log yellow "Dropping session: #{token}"
        delete @@cache[token]


export class AuthHandler extends ActorBase
    @login-delay = 10ms
    @i = 0
    (@db) ->
        super "AuthHandler.#{@@i++}"
        @session = {}
        @session-cache = new SessionCache!

        unless @db
            @log.log bg-yellow "No db supplied, only public messages are allowed."

        @on \receive, (msg) ~>
            @log.log "Processing authentication message"
            if @db
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

                            @session-cache.add @session

                            @log.log "(...sending with #{@@login-delay}ms delay)"


                            @trigger \login, @session.permissions
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
                        @session-cache.drop @session.token
                        @send auth: logout: \ok

                else if \token of msg.auth
                    if @session-cache.get msg.auth.token
                        @session = that
                    if @session.token is msg.auth.token
                        # this is a valid session token
                        @log.log "(...sending with #{@@login-delay}ms delay)"
                        @trigger \login, @session.permissions
                        <~ sleep @@login-delay
                        @send auth: session: @session
                    else
                        # means "you are not already logged in, do a logout action over there"
                        @send auth: logout: 'yes'
                else
                    @log.err yellow "Can not determine which auth request this was: ", msg
            else
                @log.log "only public messages allowed, dropping auth messages"
                @send auth: session: 'NOTAUTHORITY'


    send: (msg) -> @send-raw @msg-template msg <<< sender: @id

    send-raw: (msg) ->
        ...

    filter-incoming: (msg) ->

        if @session?permissions
            for topic in @session.permissions.rw
                if topic `topic-match` msg.topic
                    return msg
        else if msg.topic `topic-match` "public.**"
            @log.err yellow "allowing public message"
            return ms
        else
            @log.err bg-red "can not determine authorization."

        @log.err bg-red "filter-incoming dropping unauthorized message!"
        return
