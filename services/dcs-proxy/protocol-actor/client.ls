require! '../deps': {
    AuthRequest, sleep, pack, unpack
    Signal, Actor, topic-match
}
require! 'colors': {bg-red, red, bg-yellow, green, bg-green}
require! 'prelude-ls': {split, flatten, split-at, empty}
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
        @routes = []
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------
        @this-actor-is-a-proxy = yes # THIS IS VERY IMPORTANT
        # responses to the requests will be silently dropped otherwise
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------

        # Authentication protocol
        @auth = new AuthRequest @name
            ..write = (msg) ~>
                @transport.write pack msg

        @on-topic \app.dcs.update, (msg) ~>
            @send-response msg, @session

        # DCS interface
        @on \receive, (msg) ~>
            unless msg.topic `topic-match` "app.**"
                unless msg.topic `topic-match` @routes
                    @log.err "Possible coding error: We don't have permission for: ", msg
                    @log.info "Our rw permissions: ", @routes
                    @send-response msg, {err: "
                        How come the ProxyClient is subscribed a topic
                         that it has no rights to send? This is a DCS malfunction.
                        "}
                    return

                # debug
                #@log.log "Transport < DCS: (topic : #{msg.topic}) msg id: #{msg.sender}.#{msg.msg_id}"
                #@log.log "... #{pack msg.payload}"
                @transport.write (msg
                    |> @auth.add-token
                    |> pack)

        # transport interface
        @m = new MessageBinder!
        @transport
            ..on \connect, ~>
                @connected = yes
                @log.log bg-green "My transport is connected, re-logging-in."
                #@send \app.server.connect
                @transport-ready = yes
                @trigger \connect
                @trigger \_login  # triggering procedures on (re)login

            ..on \disconnect, ~>
                @connected = no
                @log.log bg-yellow "My transport is disconnected."
                @trigger \disconnect
                @send 'app.dcs.disconnect'

            ..on "data", (data) ~>
                for msg in @m.append data
                    # in "client mode", authorization checks are disabled
                    # message is only forwarded to manager
                    if \auth of msg
                        #@log.log "received auth message, forwarding to AuthRequest."
                        @auth.inbox msg
                    else
                        # debug
                        #@log.log "  Transport > DCS (topic: #{msg.topic}) msg id: #{msg.sender}.#{msg.msg_id}"
                        #@log.log "... #{pack msg.payload}"
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
                    @log.err bg-red "Something went wrong while login: ", pack(err)
                else if res.auth?error
                    @log.err bg-red "Wrong credentials?"
                else
                    @log.log bg-green "Logged in into the DCS network."
        # end of parameter normalization

        @off \_login
        @on \_login, (opts) ~>
            @log.log "sending credentials..."
            err, res <~ @auth.login credentials
            error = err or res?auth?error or (res?auth?session?logout is \yes)
            # error: if present, it means we didn't logged in succesfully.
            unless error
                @session = res.auth.session
                @routes = flatten [@session.routes]
                unless empty @routes
                    # subscribe only the messages that we have write permissions
                    # on the remote site (subscribing RO messages in the DCS
                    # network would be meaningless since they will be dropped
                    # on the remote even if we forward them.)
                    for index, topic of @subscriptions
                        unless topic `topic-match` 'app.**'
                            @subscriptions.splice index, 1
                    @subscriptions ++= @routes
                @log.info "Remote RW subscriptions: "
                for flatten [@subscriptions] => @log.info "->  #{..}"
                @log.info "Emitting app.dcs.connect"
                @send 'app.dcs.connect', @session
                @trigger \logged-in, @session, ~>
                    # clear plaintext passwords
                    credentials := {token: @session.token}
            else
                @session = null

            if res?auth?session?logout is \yes
                @trigger \kicked-out

            # re-trigger the login handler, on every re-login
            callback error, res

        # trigger logging in if we are connected already.
        if @connected => @trigger \_login

    logout: (callback) ->
        err, res <~ @auth.logout
        @log.info "Logged out; err, res: ", err, res
        @session = null
        reason = res?auth?error
        @trigger \logged-out, reason
        callback err, res
