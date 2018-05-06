require! '../deps': {AuthHandler, pack, unpack, Actor, topic-match}
require! 'colors': {bg-red, red, bg-yellow, green, bg-cyan}
require! 'prelude-ls': {split, flatten, split-at, empty}
require! './helpers': {MessageBinder}


export class ProxyHandler extends Actor
    (@transport, opts) ->
        """
        opts:
            name: name
            db: auth-db instance
        """
        super opts.name
        @log.log ">>=== New connection from the client is accepted. name: #{@name}"
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------
        @this-actor-is-a-proxy = yes # THIS IS VERY IMPORTANT
        # responses to the requests will be silently dropped otherwise
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------

        @auth = new AuthHandler opts.db, opts.name
            ..on \to-client, (msg) ~>
                @transport.write pack @msg-template msg

            ..on \login, (ctx) ~>
                @log.prefix = ctx.user
                @subscriptions = []  # renew all subscriptions
                unless empty (ctx.routes or [])
                    @log.info "subscribing routes: "
                    for flatten [ctx.routes]
                        if ..0 is \@
                            if "@#{ctx.user}.**" `topic-match` ..
                                # This is a user specific route
                                @log.info "-->  #{..}"
                                @subscribe ..
                            else
                                #@log.warn "We can't subscribe to #{..} since we are not that user."
                                null
                        else
                            @log.info "->  #{..}"
                            @subscribe ..

            ..on \logout, ~>
                # logout is specific to browser like environments, where user
                # might want to log out and log in with a different user.

                # IMPORTANT: SECURITY: Clear subscriptions
                @subscriptions = []

        # DCS to Transport
        @on do
            receive: (msg) ~>
                # debug
                #@log.log "DCS > Transport (topic : #{msg.to}) msg id: #{msg.from}.#{msg.msg_id}"
                #@log.log "... #{pack msg.payload}"
                @transport.write pack msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"

        # Transport to DCS
        @m = new MessageBinder!
        @transport
            ..on "data", (data) ~>
                #@log.log "________data:", data.to-string!
                for msg in @m.append data
                    # in "client mode", authorization checks are disabled
                    # message is only forwarded to manager
                    if \auth of msg
                        #@log.log green "received auth message: ", msg
                        @auth.trigger \check-auth, msg
                    else
                        try
                            msg
                            |> @auth.modify-sender
                            |> @auth.check-routes
                            |> @send-enveloped
                        catch
                            if e.type is \AuthError
                                @log.warn "Authorization failed, dropping message."
                                console.log msg
                            else
                                throw e

            ..on \disconnect, ~>
                @log.log "proxy handler is exiting."
                @kill \disconnected
