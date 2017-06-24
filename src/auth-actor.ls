require! './actor': {Actor}
require! 'prelude-ls': {find}
require! './signal': {Signal}
require! 'aea': {sleep, clone}

class LocalStorage
    (@name) ->
        @s = local-storage

    set: (key, value) ->
        @s.set-item key, value

    del: (key) ->
        @s.remove-item key

    get: (key) ->
        @s.get-item key


# AuthActor can interact with SocketIOBrowser
export class AuthActor extends Actor
    @instance = null
    ->
        return @@instance if @@instance
        @@instance = this

        super 'AuthActor'
        @db = new LocalStorage \auth

    post-init: ->
        @io-actor = find (.name is \SocketIOBrowser), @mgr.actor-list
        @login-signal = new Signal!
        @logout-signal = new Signal!
        @check-signal = new Signal!
        @checking = no
        @io-actor.on 'network-receive', (msg) ~>
            if \auth of msg
                #@log.log "Auth actor got authentication message", msg
                if \session of msg.auth
                    @login-signal.go msg
                else if \logout of msg.auth
                    if msg.auth.logout is \ok
                        @logout-signal.go msg

                @check-signal.go msg

    login: (credentials, callback) ->
        @send-to-remote auth: credentials
        reason, res <~ @login-signal.wait 3000ms
        err = if reason is \timeout
            {reason: \timeout}
        else
            no

        # set socketio-browser's token variable in order to use it in every message
        @io-actor.token = try
            res.auth.session.token
        catch
            err = {reason: 'something wrong with token'}
            void

        @db.set \token, @io-actor.token
        callback err, res

    logout: (callback) ->
        @send-to-remote auth: logout: yes
        reason, msg <~ @logout-signal.wait 3000ms
        err = if reason is \timeout
            {reason: 'timeout'}
        else
            no

        if not err and msg.auth.logout is \ok
            @log.log "clearing local storage"
            @db.del \token

        callback err, msg

    check-session: (callback) ->
        if @checking
            callback {code: 'singleton', reason: 'checking already'}
            @log.log "checking already..."
            return
        @checking = yes
        token = @db.get \token
        @send-to-remote auth: token: token
        reason, msg <~ @check-signal.wait 5000ms
        #@db.del \token
        @log.log "server responded check-session with: ", msg
        err = if reason is \timeout
            {reason: 'server not responded in a reasonable amount of time'}
        else
            no

        if msg.auth.session
            @io-actor.token = msg.auth.session.token

        callback err, msg
        @checking = no

    send-to-remote: (msg) ->
        msg.sender = @actor-id
        enveloped-message = @io-actor.msg-template msg
        @io-actor.network-send-raw enveloped-message
