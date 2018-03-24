require! './helpers': {MessageBinder}
require! '../src/auth-request': {AuthRequest}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue, bg-green}
require! '../lib': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at, empty}
require! '../src/signal':{Signal}
require! '../src/actor': {Actor}
require! '../src/topic-match': {topic-match}

"""
Description
-------------
This is a Protocol Suit: A Connector without transport

    * Message format: Transparent,
    * Has Actor,
    * Protocol: AuthRequest

Takes a transport, transparently connects two DCS networks with each other.
"""
export class ProxyClient extends Actor
    (@transport, @opts) ->
        super \ProxyClient

    action: ->
        # actor behaviours
        @role = \client
        @connected = no
        @data-binder = new MessageBinder!
        @proxy = yes
        @permissions-rw = []

        # Authentication protocol
        @auth = new AuthRequest!
            ..on \to-server, (msg) ~>
                @transport.write pack msg

            ..on \login, (permissions) ~>
                @permissions-rw = flatten [permissions.rw]
                unless empty @permissions-rw
                    @log.log "logged in succesfully. subscribing to: ", @permissions-rw
                    @subscribe @permissions-rw
                    @log.log "requesting update messages for subscribed topics"
                    for topic in @permissions-rw
                        {topic, +update}
                        |> @msg-template
                        |> @auth.add-token
                        |> pack
                        |> @transport.write
                else
                    @log.warn "logged in, but there is no rw permissions found."

        @on do
            receive: (msg) ~>
                #@log.log "forwarding received DCS message #{msg.topic} to TCP transport"
                unless msg.topic `topic-match` @permissions-rw
                    @send-response msg, {err: "
                        How come the ProxyClient is subscribed a topic
                        that it has no rights to send? This is a DCS malfunction.
                        "}
                    return

                err <~ @transport.write (msg
                    |> @auth.add-token
                    |> pack)
                /* Success status is not used for now
                if err
                    console.err "could not sent the data..."
                else
                    console.log "written to transport successfully..."
                */

        # ----------------------------------------------
        #            network interface events
        # ----------------------------------------------
        @transport
            ..on \connect, ~>
                @connected = yes
                @log.log bg-green "My transport is connected."
                @transport-ready = yes
                err, res <~ @trigger \_login, {forget-password: @opts.forget-password}  # triggering procedures on (re)login
                @subscribe "public.**"

            ..on \disconnect, ~>
                @connected = no
                @log.log bg-yellow "My transport is disconnected."

            ..on "data", (data) ~>
                # in "client mode", authorization checks are disabled
                # message is only forwarded to manager
                for msg in @data-binder.get-messages data
                    if \auth of msg
                        #@log.log "received auth message, forwarding to AuthRequest."
                        @auth.trigger \from-server, msg
                    else
                        #@log.log "received data: ", pack msg
                        @send-enveloped msg

    login: (credentials, callback) ->
        # normalize parameters
        if typeof! credentials is \Function
            callback = credentials
            credentials = null

        @off \_login
        @on \_login, (opts) ~>
            @log.log "sending credentials..."
            err, res <~ @auth.login credentials
            if opts?.forget-password
                #@log.warn "forgetting password"
                credentials := token: try
                    res.auth.session.token
                catch
                    null
            unless err
                @trigger \logged-in

            callback err, res

        if @connected
            @trigger \_login, {forget-password: @opts.forget-password}

    logout: (callback) ->
        @auth.logout callback
