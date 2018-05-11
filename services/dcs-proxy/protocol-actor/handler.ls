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
        @request-table = {}

        @auth = new AuthHandler opts.db, opts.name
            ..on \to-client, (msg) ~>
                if msg.debug
                    @log.log "Debugging message: ", msg
                {from: @me, seq: @msg-seq++} <<< msg
                |> pack
                |> @transport.write

            ..on \login, (ctx) ~>
                @log.prefix = ctx.user
                @subscriptions = []  # renew all subscriptions
                unless empty (ctx.routes or [])
                    @log.info "subscribing routes: "
                    for flatten [ctx.routes]
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
                try
                    msg
                    |> (m) ~>
                        unless m.from `topic-match` "@#{m.user}.**"
                            @log.debug "Dropping user specific route: ", m
                            throw do
                                type: \NORMAL
                                message: "User broadcast route, we are not that user."

                        if m.re?
                            # this is a response, check if we were expecting it
                            #@log.debug "Checking if we are expecting #{m.to}"
                            response-id = "#{m.to}.#{m.re}"
                            unless @request-table[response-id]
                                error = "Not our response."
                                #@log.debug "Dropping response: #{error}, resp: #{response-id}"
                                throw {type: \NORMAL, message: error}
                            else
                                unless m.part? or m.part is -1
                                    #"Last part of our expected response, removing from table." |> @log.debug
                                    delete @request-table[response-id]
                        return m
                    |> (m) ~>
                        if m.req and "@#{@auth.session.user}.**" `topic-match` m.to
                            @log.todo "Add response token here. me: #{@auth.session.user}, msg: ", m
                        m
                    |> pack
                    |> @transport.write
                catch
                    switch e.type
                    | "NORMAL" => null
                    |_ => throw e

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
                    if msg.debug
                        @log.log "Debugging message: ", msg

                    if \auth of msg
                        #@log.log green "received auth message: ", msg
                        @auth.trigger \check-auth, msg
                    else
                        try
                            msg
                            |> (m) ~>
                                if m.re?
                                    @log.todo "Check response token here."
                                return m
                            |> @auth.modify-sender
                            |> @auth.add-ctx
                            |> (m) ~>
                                if m.req
                                    #@log.debug "adding response route for #{m.from}"
                                    @request-table["#{m.from}.#{m.seq}"] = yes
                                return m
                            |> @auth.check-routes
                            |> @send-enveloped
                        catch
                            if e.type is \AuthError
                                @log.warn "Authorization failed, dropping message."
                                @log.warn "dropped message: ", msg
                            else
                                throw e

            ..on \disconnect, ~>
                @log.log "proxy handler is exiting."
                @kill \disconnected
