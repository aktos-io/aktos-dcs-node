require! './actor': {Actor}
require! 'prelude-ls': {find}
require! './signal': {Signal}

# AuthActor can interact with SocketIOBrowser
export class AuthActor extends Actor
    ->
        super 'AuthActor'

    post-init: ->
        @io-actor = find (.name is \SocketIOBrowser), @mgr.actor-list
        @login-signal = new Signal!

        @io-actor.on 'network-receive', (msg) ~>
            if \auth of msg
                @log.log "Auth actor got authentication message", msg
                @login-signal.go msg

    login: (callback) ->
        auth-msg = @io-actor.msg-template do
            auth:
                username: \user1
                password: 'hello world'

        @log.log "sending auth message: ", auth-msg
        @io-actor.network-send-raw auth-msg
        reason, res <~ @login-signal.wait 3000ms 
        if reason is \timeout
            @login-signal.skip-next-go!
            return
        @log.log "signal triggered because #{reason}, response is: ", res
        callback res
