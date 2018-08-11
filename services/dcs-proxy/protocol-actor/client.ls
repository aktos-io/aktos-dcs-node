require! '../deps': {
    AuthRequest, sleep, pack, unpack
    Signal, Actor, topic-match, clone, brief
}
require! 'prelude-ls': {split, flatten, split-at, empty, reject}
require! './helpers': {MessageBinder}


'''
Description
-------------
This is a Protocol Actor: A service without transport

    * Message format: Transparent,
    * Has Actor,
    * Protocol: AuthRequest

Takes a transport, transparently connects two DCS networks with each other.

## Events:

on login: emit "app.dcs.connect" message.

'''



export class ProxyClient extends Actor
    (@transport, @opts) ->
        super (@opts.name  or \ProxyClient)

    action: ->
        # actor behaviours
        @role = \client
        @connected = no
        @session = null
        @_transport_busy = no

        # Authentication protocol
        @auth = new AuthRequest @name
            ..write = (msg) ~>
                @transport.write pack msg

        @on-topic \app.dcs.update, (msg) ~>
            debug = no
            if debug
                @log.debug "Received connection status update: ", msg
            #@log.debug "Sending session information: ", @session
            @send-response msg, {debug}, @session

        @on \disconnect, ~>
            @subscriptions = reject (~> it `topic-match` @session?.routes), @subscriptions
            @session = null

        # DCS to Transport
        @on \receive, (msg) ~>
            unless msg.to `topic-match` "app.**"
                unless msg.to `topic-match` @subscriptions
                    @log.err "Possible coding error: We don't have a route for: ", msg
                    @log.info "Our subscriptions: ", @subscriptions
                    @send-response msg, {err: "
                        How come the ProxyClient is subscribed a topic
                         that it has no rights to send? This is a DCS malfunction.
                        "}
                    return

                # debug
                #@log.log "Transport < DCS: (topic : #{msg.to}) msg id: #{msg.from}.#{msg.msg_id}"
                #@log.log "... #{pack msg.data}"
                if @_transport_busy
                    @log.err "Transport was busy, we shouldn't try to send ", msg
                    @log.info "...will retry to write to transport in 500ms."
                    debugger
                    sleep 500ms, ~>
                        @trigger \receive, msg
                    return

                @_transport_busy = yes
                msg
                |> (m) ~>
                    if m.debug
                        @log.debug "Forwarding DCS to transport: ", brief m
                    if m.re?
                        response-id = "#{m.to}"
                        #@log.debug "this is a response message: #{response-id}"
                        if not m.part? or m.part is -1
                            #console.log "...last part or has no part, unsubscribing
                            #    from transient subscription"
                            @unsubscribe response-id
                    return m
                |> @auth.add-token
                |> pack
                |> (s) ~>
                    if msg.debug
                        @log.debug "Sending #{msg.seq}->#{msg.to} size: #{s.length}"
                    return (pack {size: s.length}) + s
                |> @transport.write

                if msg.debug
                    @log.debug "Data is sent."
                @_transport_busy = no

        # Transport to DCS
        @m = new MessageBinder!
        total-delay = 0
        @transport
            ..on \connect, ~>
                @connected = yes
                @log.success "My transport is connected, re-logging-in."
                #@send \app.server.connect
                @transport-ready = yes
                @trigger \connect
                @trigger \_login  # triggering procedures on (re)login

            ..on \disconnect, ~>
                @connected = no
                @log.warn "My transport is disconnected."
                @trigger \disconnect
                @send 'app.dcs.disconnect'

            ..on "data", (data) ~>
                t0 = Date.now!
                x = @m.append data
                total-delay := total-delay + (Date.now! - t0)
                for msg in x
                    if total-delay > 100ms
                        @log.debug "....time spent for concatenating: #{total-delay}ms"
                    total-delay := 0

                    # in "client mode", authorization checks are disabled
                    # message is only forwarded to manager
                    if \auth of msg
                        #@log.log "received auth message, forwarding to AuthRequest."
                        @auth.inbox msg
                    else
                        if msg.debug
                            @log.debug "Forwarding Transport to DCS:", brief msg
                        if msg.req
                            # subscribe for possible response
                            response-route = "#{msg.from}"
                            if msg.debug
                                @log.debug "Transient subscription to response route: #{response-route}"
                            @subscribe response-route
                            #console.log "subscriptions: ", @subscriptions
                        if msg.re?
                            # directly pass to message owner
                            #@log.debug "forwarding a Response message to actor: ", msg
                            msg.to = msg.to.replace "@#{@session.user}.", ''
                            if @mgr.find-actor msg.to
                                that._inbox msg
                            if msg.cc
                                msg2 = clone msg
                                msg2.to = msg.cc
                                msg2._exclude = msg.to # already sent above
                                @send-enveloped msg2
                            return
                        @send-enveloped msg

    login: (credentials, callback) ->
        # normalize parameters
        # ----------------------------------------------------
        if typeof! credentials is \Function
            callback = credentials
            credentials = null
        else if not callback
            # default callback
            callback = (err, res) ~>
                if err
                    @log.err "Something went wrong while login: ", pack(err)
                else if res.auth?error
                    @log.err "Wrong credentials?"
                else
                    @log.success "Logged in into the DCS network."
        # end of parameter normalization

        @off \_login
        @on \_login, (opts) ~>
            @log.log "sending credentials..."
            err, res <~ @auth.login credentials
            error = err or res?auth?error or (res?auth?session?logout is \yes)
            # error: if present, it means we didn't logged in succesfully.
            unless error
                @session = res.auth.session
                #@log.debug "Current @session.routes: ", @subscriptions
                #@log.debug "Routes from server: ", @session.routes
                @subscriptions ++= @session.routes
                @log.info "Remote route subscriptions: "
                for flatten [@subscriptions] => @log.info "->  #{..}"
                @log.info "Emitting app.dcs.connect"
                @send 'app.dcs.connect', @session
                @trigger \logged-in, @session, ~>
                    # clear plaintext passwords
                    credentials := {token: @session.token}
            else
                @trigger \disconnect

            if res?auth?session?logout is \yes
                @trigger \kicked-out

            # re-trigger the login handler, on every re-login
            callback error, res

        # trigger logging in if we are connected already.
        if @connected => @trigger \_login

    logout: (callback) ->
        err, res <~ @auth.logout
        @log.info "Logged out; err, res: ", err, res
        @trigger \disconnect
        reason = res?auth?error
        @trigger \logged-out, reason
        callback err, res
