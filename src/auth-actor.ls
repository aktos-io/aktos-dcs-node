require! './actor': {Actor}
require! 'prelude-ls': {find}

# AuthActor can interact with SocketIOBrowser
export class AuthActor extends Actor
    ->
        super 'AuthActor'

    post-init: ->
        @io-actor = find (.name is \SocketIOBrowser), @mgr.actor-list
        #@log.log "socket io browser instance: ", @io-actor

        @io-actor.on 'network-receive', (msg) ~>
            @log.log "heyyyyyyyyyy", msg
            if \auth of msg
                @log.log "Auth actor got authentication message", msg


    login: ->
        auth-msg = @io-actor.get-msg-template!
        auth-msg.auth =
            username: \user1
            password: 'hello world'

        @log.log "sending auth message: ", auth-msg
        @io-actor.network-send-raw auth-msg
