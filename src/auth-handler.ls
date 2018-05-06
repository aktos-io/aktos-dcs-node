require! './signal': {Signal}
require! '../lib': {sleep, Logger, pack, EventEmitter}
require! 'uuid4'
require! 'colors': {
    red, green, yellow,
    bg-red, bg-yellow, bg-green
    bg-cyan
}
require! './auth-helpers': {hash-passwd, AuthError}
require! './topic-match': {topic-match}
require! './errors': {CodingError}

class SessionCache
    @cache = {}
    @instance = null
    ->
        return @@instance if @@instance
        @@instance = this
        @log = new Logger \SessionCache
        @log.log green "SessionCache is initialized", pack @@cache

    add: (session) ->
        @log.log green "Adding session for #{session.user}", (yellow session.token)
        @@cache[session.token] = session

    get: (token) ->
        @@cache[token]

    drop: (token) ->
        @log.log yellow "Dropping session for user: #{@@cache[token].user} token: #{token}"
        delete @@cache[token]


export class AuthHandler extends EventEmitter
    @login-delay = 10ms
    @i = 0
    (db, name) ->
        db? or throw new CodingError "AuthDB instance is required."

        super!
        @log = new Logger (name or "AuthHandler.#{@@i++}")
        @session-cache = new SessionCache!

        @on \check-auth, (msg) ~>
            #@log.log "Processing authentication message", msg

            if \user of msg.auth
                try
                    user = db.get msg.auth.user
                    if user.passwd-hash is msg.auth.password
                        session =
                            token: uuid4!
                            user: msg.auth.user
                            date: Date.now!
                            routes: user.routes

                        @session-cache.add session
                        @log.log bg-green "new Login: #{msg.auth.user} (#{session.token})"
                        @log.log "(...sending with #{@@login-delay}ms delay)"
                        @trigger \login, session
                        <~ sleep @@login-delay
                        @trigger \to-client, do
                            auth:
                                session: session
                    else
                        @log.err "wrong password", doc, msg.auth.password
                        @trigger \to-client, do
                            auth:
                                error: "wrong password"
                catch
                    @log.err "user \"#{msg.auth.user}\" is not found. err: ", e
                    @trigger \to-client, do
                        auth:
                            error: e


            else if \logout of msg.auth
                # session end request
                unless @session-cache.get msg.token
                    @log.log bg-yellow "No user found with the following token: #{msg.token} "
                    @trigger \to-client, do
                        auth:
                            logout: \ok
                            error: "no such user found"
                    @trigger \logout
                else
                    @log.log "logging out for #{pack (@session-cache.get msg.token)}"
                    @session-cache.drop msg.token
                    @trigger \to-client, do
                        auth:
                            logout: \ok
                    @trigger \logout

            else if \token of msg.auth
                @log.log "Attempting to login with token: ", pack msg.auth
                if (@session-cache.get msg.auth.token)?.token is msg.auth.token
                    # this is a valid session token
                    found-session = @session-cache.get(msg.auth.token)
                    @log.log bg-cyan "User \"#{found-session.user}\" has been logged in with token."
                    @trigger \login, found-session
                    <~ sleep @@login-delay
                    @trigger \to-client, do
                        auth:
                            session: found-session
                else
                    # means "you are not already logged in, do a logout action over there"
                    @log.log bg-yellow "client doesn't seem to be logged in yet."
                    <~ sleep @@login-delay
                    @trigger \to-client, do
                        auth:
                            session:
                                logout: 'yes'
            else
                @log.err yellow "Can not determine which auth request this was: ", pack msg


    check-routes: (msg) ->
        #@log.log yellow "filter-incoming: input: ", pack msg
        session = @session-cache.get msg.token
        # remove username from route
        if session
            # check if this actor has rights to send to that route
            for session.routes
                if .. `topic-match` msg.to
                    delete msg.token
                    return msg
            # check if this is a response message,
            if msg.re
                # FIXME: provide a token authentication per response message
                delete msg.token
                return msg

        @log.err (bg-red "filter-incoming dropping unauthorized message!"),
        throw new AuthError 'unauthorized message route'

    modify-sender: (msg) ->
        session = @session-cache.get msg.token
        msg.from = "@#{session.user}.#{msg.from}"
        return msg
