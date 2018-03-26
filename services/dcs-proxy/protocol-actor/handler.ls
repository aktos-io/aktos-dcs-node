require! '../deps': {AuthHandler, pack, unpack, Actor}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'prelude-ls': {split, flatten, split-at}
require! './helpers': {MessageBinder}


export class ProxyHandler extends Actor
    (@transport, opts) ->
        """
        opts:
            name: name
            db: auth-db instance
        """
        super opts.name
        @subscribe "public.**"
        @log.log ">>=== New connection from the client is accepted. name: #{@name}"
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------
        @proxy = yes # THIS IS VERY IMPORTANT
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------

        @auth = new AuthHandler opts.db, opts.name
            ..on \to-client, (msg) ~>
                @transport.write pack @msg-template msg

            ..on \login, (ctx) ~>
                @log.name = "#{ctx.user}/#{@log.name}"

                subscriptions = ctx.permissions
                @log.log bg-blue "subscribing readonly: ", subscriptions.ro
                @subscribe subscriptions.ro

                @log.log bg-yellow "subscribing read/write: ", subscriptions.rw
                @subscribe subscriptions.rw

                @log.log "Handler subscriptions so far: "
                for @subscriptions => @log.log "++ #{..}"

            ..on \logout, ~>
                ...
                # this is an unreachable code, since "logout" can only be
                # handled by creator of this actor

        # DCS interface
        @on do
            receive: (msg) ~>
                @log.log "DCS > Transport (topic : #{msg.topic}) msg id: #{msg.sender}.#{msg.msg_id}"
                @log.log "... #{pack msg.payload}"
                @transport.write pack msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"

        # transport interface
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
                            |> @auth.check-permissions
                            # permission check ok, send to DCS network
                            #|> (x) -> console.log "permissions okay for #{x.sender}.#{x.msg_id}"; return x
                            |> @send-enveloped

                            @log.log "  Transport > DCS (topic: #{msg.topic}) msg id: #{msg.sender}.#{msg.msg_id}"
                            @log.log "... #{pack msg.payload}"
                        catch
                            @log.warn "TODO: RETHROW IF NEEDED: Authorization failed, dropping (silently)"

            ..on \disconnect, ~>
                @log.log "proxy handler is exiting."
                @kill \disconnected
