require! './signal': {Signal}
require! '../lib': {sleep, pack, clone, EventEmitter, Logger}
require! 'colors': {red, green, yellow, bg-red, bg-yellow}
require! './auth-helpers': {hash-passwd}
require! './topic-match': {topic-match}
require! 'prelude-ls': {keys, join}

export class AuthRequest
    @i = 0
    (name) ->
        @log = new Logger (name or "AuthRequest.#{@@i++}")
        @reply-signal = new Signal!

    inbox: (msg) ->
        @reply-signal.go msg

    login: (_credentials={}, callback) ->
        # credentials might be one of the following:
        # 1. {username: ..., password: ...}
        # 2. {token: ...}

        credentials = clone _credentials
        if credentials.password
            # username, password
            credentials.password = hash-passwd credentials.password

        else if credentials.token?
            @log.info "token is: ", credentials
            # token
            if credentials.token.length < 10
                err = "Token seems empty, not attempting to login."
                @log.log err
                callback err="Not a valid token", null
                return

        @log.log "Trying to authenticate with", (keys credentials .join ', ')

        if keys credentials .length is 0
            @log.warn "Credentials empty! (why? is server restarted?)"
            callback err="EMPTY_CREDENTIALS"
            return

        @write {auth: credentials}
        @reply-signal.clear!
        err, res <~ @reply-signal.wait 3000ms
        #@log.log "auth replay is: ", pack res
        if res?auth?session?token
            @token = that
        callback (err or res?auth?error), res

    logout: (callback) ->
        @write @add-token {auth: logout: yes}
        err, msg <~ @reply-signal.wait 3000ms
        if not err and msg.auth.logout is \ok
            @log.log "clearing token from AuthRequest cache"
            @token = null
        callback err, msg

    add-token: (msg) ->
        return msg <<< {token: @token}
