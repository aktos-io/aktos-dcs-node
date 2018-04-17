require! './signal': {Signal}
require! '../lib': {sleep, pack, clone, EventEmitter, Logger}
require! './authorization':{get-all-permissions}
require! 'uuid4'
require! 'colors': {red, green, yellow, bg-red, bg-yellow}
require! './auth-helpers': {hash-passwd}
require! './topic-match': {topic-match}
require! 'prelude-ls': {keys, join}

export class AuthRequest extends EventEmitter
    @i = 0
    (name) ->
        super!
        @log = new Logger (name or "AuthRequest.#{@@i++}")
        @reply-signal = new Signal!

        @on \from-server, (msg) ->
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
                @trigger \logout
                callback err="Not a valid token", null
                return

        @log.log "Trying to authenticate with", keys credentials

        if keys credentials .length is 0
            @log.warn "Credentials empty! (why? is server restarted?)"
            callback err="EMPTY_CREDENTIALS"
            return

        @trigger \to-server, {auth: credentials}

        @reply-signal.clear!
        err, res <~ @reply-signal.wait 3000ms
        #@log.log "auth replay is: ", pack res
        try
            unless err
                if res.auth.error
                    @log.log "AUTH_ERR: ", res.auth
                    @trigger \logout, {code: "AUTH_ERR", res: res.auth}
                else
                    if res.auth.session.token
                        # store token in order to use in every message
                        @token = that
                        @trigger \login, res.auth.session.permissions
                    else if res.auth.session.logout is \yes
                        @log.log "KICKED: ", res.auth
                        @trigger \logout, {code: 'KICKED'}
        catch
            @log.err "something went wrong here: ex: ", e, "res: ", res, "err:", err
            err = e

        callback err, res

    logout: (callback) ->
        @trigger \to-server, @add-token {auth: logout: yes}
        err, msg <~ @reply-signal.wait 3000ms
        if not err and msg.auth.logout is \ok
            @log.log "clearing token from AuthRequest cache"
            @token = null
        @trigger \logout, {code: 'GRACEFUL'}
        callback err, msg

    add-token: (msg) ->
        return msg <<< {token: @token}
