require! './actor-base': {ActorBase}
require! './signal': {Signal}
require! 'aea': {sleep, pack, clone}
require! './authorization':{get-all-permissions}
require! 'uuid4'
require! 'colors': {red, green, yellow, bg-red, bg-yellow}
require! 'aea/debug-log': {logger}
require! './auth-helpers': {hash-passwd}
require! './topic-match': {topic-match}
require! 'prelude-ls': {keys, join}

export class AuthRequest extends ActorBase
    @i = 0
    ->
        super "AuthRequest.#{@@i++}"
        @reply-signal = new Signal!

    inbox: (msg) ->
        @reply-signal.go msg

    login: (_credentials, callback) ->
        # credentials might be one of the following:
        # 1. {username: ..., password: ...}
        # 2. {token: ...}

        credentials = clone _credentials
        if credentials.password
            credentials.password = hash-passwd credentials.password

        @log.log "Trying to authenticate with", keys credentials

        if \token of credentials
            if credentials.token.length < 10
                err = "Token seems empty, not attempting to login."
                @log.log err
                @trigger \logout
                callback err, null
                return

        @send auth: credentials
        # FIXME: why do we need to clear the signal?
        @reply-signal.clear!
        err, res <~ @reply-signal.wait 3000ms
        #@log.log "auth replay is: ", pack res
        try
            unless err
                if res.auth.error
                    @trigger \logout
                else
                    if res.auth.session.token
                        # store token in order to use in every message
                        @token = that
                        @trigger \login, res.auth.session.permissions
                    else if res.auth.session.logout is \yes
                        @trigger \logout
        catch
            @log.err "something went wrong here: ex: ", e, "res: ", res, "err:", err

        callback err, res

    logout: (callback) ->
        @send-with-token auth: logout: yes
        err, msg <~ @reply-signal.wait 3000ms
        if not err and msg.auth.logout is \ok
            @log.log "clearing token from AuthRequest cache"
            @token = null

        callback err, msg

    send: (msg) ->
        @send-raw @msg-template msg <<< sender: @id

    send-with-token: (msg) ->
        #@log.log "sending message: #{pack msg}"
        @send-raw msg <<< token: @token

    send-raw: (msg) ->
        ...
