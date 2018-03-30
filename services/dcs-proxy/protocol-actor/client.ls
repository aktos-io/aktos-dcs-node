require! '../deps': {
    AuthRequest, sleep, pack, unpack
    Signal, Actor, topic-match
}
require! 'colors': {bg-red, red, bg-yellow, green, bg-green}
require! 'prelude-ls': {split, flatten, split-at, empty}
require! './helpers': {MessageBinder}

"""
Description
-------------
This is a Protocol Actor: A Connector without transport

    * Message format: Transparent,
    * Has Actor,
    * Protocol: AuthRequest

Takes a transport, transparently connects two DCS networks with each other.


on login: emit "app.logged-in"

"""
export class ProxyClient extends Actor
    (@transport, @opts) ->
        super (@opts.name  or \ProxyClient)

    action: ->
        # actor behaviours
        @role = \client
        @connected = no
        @permissions-rw = []
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------
        @this-actor-is-a-proxy = yes # THIS IS VERY IMPORTANT
        # responses to the requests will be silently dropped otherwise
        # ------------------------------------------------------
        # ------------------------------------------------------
        # ------------------------------------------------------

        # Authentication protocol
        @auth = new AuthRequest!
            ..on \to-server, (msg) ~>
                @transport.write pack msg

            ..on \login, (permissions) ~>
                @permissions-rw = flatten [permissions.rw]
                unless empty @permissions-rw
                    # subscribe only the messages that we have write permissions
                    # on the remote site (subscribing RO messages in the DCS
                    # network would be meaningless since they will be dropped
                    # on the remote even if we forward them.)
                    @subscriptions = @permissions-rw

                    # request update messages that we interested in
                    @log.log "requesting update messages for subscribed topics"
                    for topic in @permissions-rw
                        {topic, +update}
                        |> @msg-template
                        |> @auth.add-token
                        |> pack
                        |> @transport.write
                else
                    @log.warn "Logged in, but there is no rw permissions found."

                @log.info "Remote RW subscriptions: "
                for flatten [@subscriptions] => @log.info "->  #{..}"

                @log.info "Emitting app.logged-in"
                @send 'app.logged-in', {}

        # DCS interface
        @on do
            receive: (msg) ~>
                unless msg.topic `topic-match` @permissions-rw
                    @log.warn "We don't have permission for: ", msg
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
                @log.log bg-green "My transport is connected."
                @transport-ready = yes
                err, res <~ @trigger \_login, {forget-password: @opts.forget-password}  # triggering procedures on (re)login
                @subscribe "public.**"

            ..on \disconnect, ~>
                @connected = no
                @log.log bg-yellow "My transport is disconnected."

            ..on "data", (data) ~>
                for msg in @m.append data
                    # in "client mode", authorization checks are disabled
                    # message is only forwarded to manager
                    if \auth of msg
                        #@log.log "received auth message, forwarding to AuthRequest."
                        @auth.trigger \from-server, msg
                    else
                        # debug
                        #@log.log "  Transport > DCS (topic: #{msg.topic}) msg id: #{msg.sender}.#{msg.msg_id}"
                        #@log.log "... #{pack msg.payload}"
                        @send-enveloped msg

    login: (credentials, callback) ->
        # normalize parameters
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
