require! '../deps': {AuthHandler, pack, unpack, Actor, topic-match, brief, sleep}
require! 'colors': {bg-red, red, bg-yellow, green, bg-cyan}
require! 'prelude-ls': {split, flatten, split-at, empty}
require! './helpers': {MessageBinder}
require! 'uuid4'


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
        @_transport_busy = no

        @auth = new AuthHandler opts.db, opts.name
            ..on \to-client, (msg) ~>
                {from: @me, seq: @msg-seq++} <<< msg
                |> (m) ~>
                    if m.debug
                        @log.debug "Sending to transport by AuthHandler:", m
                    return m
                |> pack
                |> @transport.write

            ..on \login, (ctx) ~>
                @log.prefix = ctx.user
                @user = ctx.user
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
                if @_transport_busy
                    @log.err "Transport was busy, we shouldn't try to send ", msg
                    @log.info "...will retry to write to transport in 500ms."
                    debugger
                    sleep 500ms, ~>
                        @trigger \receive, msg
                    return

                try
                    @_transport_busy = yes
                    t0 = Date.now!
                    msg
                    |> (m) ~>
                        if m.debug
                            @log.debug "Forwarding from DCS to Transport: ", brief m
                        try
                            if m.re?
                                # this is a response, check if we were expecting it
                                #@log.debug "Checking if we are expecting #{m.to}"
                                response-id = "#{m.to}.#{m.re}"
                                unless @request-table[response-id]
                                    error = "Not our response."
                                    #@log.debug "Dropping response: #{error}, resp: #{response-id}"
                                    throw {type: \NORMAL, message: error}
                                else if @request-table[response-id] isnt m.res-token
                                    message = "Response token is not correct, dropping message.
                                        expecting #{@request-table[response-id]}, got: #{m.res-token}"
                                    delete @request-table[response-id]
                                    throw {type: \HACK, message}
                                else
                                    unless m.part? or m.part is -1
                                        #"Last part of our expected response, removing from table." |> @log.debug
                                        delete @request-table[response-id]
                                delete m.res-token  # remove unnecessary data

                                return m
                        catch
                            # still move forward if it has carbon copy attribute
                            unless m.cc
                                throw e

                        unless m.from `topic-match` "@#{m.user}.**"
                            message = "Dropping user specific route message"
                            if m.debug
                                @log.debug message, brief m
                            throw {type: \NORMAL, message}

                        if m.to.0 is \@
                            # this is a username specific route
                            unless m.to `topic-match` "@#{@user}.**"
                                message = "Dropping user specific route message (to: #{m.to}, user: #{@user})"
                                if m.debug
                                    @log.debug message #, brief m
                                throw {type: \NORMAL, message}
                        return m
                    |> pack
                    |> (s) ~>
                        #@log.debug "writing size: #{s.length}"
                        {size: s.length}
                        |> pack
                        |> @transport.write
                        return s
                    |> @transport.write

                    if msg.debug
                        @log.debug "sending took: #{Date.now! - t0}ms"
                catch
                    switch e.type
                    | "NORMAL" => null
                    |_ => @log.err e.message

                finally
                    @_transport_busy = no

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"

        # Transport to DCS
        @m = new MessageBinder!
        @transport
            ..on "data", (data) ~>
                #@log.debug "________data: #{parse-int data.to-string!.length/1024}KB"
                for msg in @m.append data
                    # in "client mode", authorization checks are disabled
                    # message is only forwarded to manager
                    if msg.debug
                        @log.debug "Transport to DCS:", brief msg

                    if \auth of msg
                        #@log.log green "received auth message: ", msg
                        @auth.trigger \check-auth, msg
                    else
                        try
                            msg
                            |> @auth.modify-sender
                            |> @auth.add-ctx
                            |> (m) ~>
                                if m.req
                                    #@log.debug "adding response route and token for #{m.from}"
                                    token = uuid4!
                                    @request-table["#{m.from}.#{m.seq}"] = token
                                    m.res-token = token
                                return m
                            |> @auth.check-routes
                            |> @send-enveloped
                        catch
                            if e.type is \AuthError
                                @log.warn "Authorization failed, dropping message."
                                @log.warn "dropped message: ", brief msg
                            else
                                throw e

            ..on \disconnect, ~>
                @log.log "proxy handler is exiting."
                @kill \disconnected
