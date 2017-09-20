require! './helpers': {MessageBinder}
require! '../src/auth-request': {AuthRequest}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}
require! '../src/signal':{Signal}
require! '../src/actor': {Actor}


export class ProxyClient extends Actor
    (@socket, @opts) ->
        super \ProxyClient

    action: ->
        # actor behaviours
        @role = \client
        @connected = no
        @data-binder = new MessageBinder!

        @auth = new AuthRequest!
            ..on \to-server, (msg) ~>
                @socket.write pack msg

            ..on \login, (permissions) ~>
                topics = permissions.rw
                @log.log "logged in succesfully. subscribing to: ", topics
                @subscribe topics
                @log.log "requesting update messages for subscribed topics"
                for topic in topics
                    {topic, +update}
                    |> @msg-template
                    |> @auth.add-token
                    |> pack
                    |> @socket.write

        @on do
            receive: (msg) ~>
                #@log.log "forwarding message #{msg.topic} to network interface"
                if @socket-ready
                    msg
                    |> @auth.add-token
                    |> pack
                    |> @socket.write
                else
                    @log.log bg-yellow "Socket not ready, not sending message: "
                    console.log "msg is: ", msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"
                @socket
                    ..end!
                    ..destroy 'KILLED'

            needReconnect: ~>
                @socket-ready = no

            connected: ~>
                @log.log "<<=== New proxy connection to the server is established. name: #{@name}"
                @socket-ready = yes
                @trigger \relogin, {forget-password: @opts.forget-password}  # triggering procedures on (re)login
                @subscribe "public.**"


        # ----------------------------------------------
        #            network interface events
        # ----------------------------------------------
        @socket
            ..on \connect, ~>
                @trigger \connected
                @connected = yes

            ..on \disconnect, ~>
                @log.log "Client disconnected."
                @connected = no

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

            ..on \error, (e) ~>
                if e.code in <[ EPIPE ECONNREFUSED ECONNRESET ETIMEDOUT ]>
                    @log.err red "Socket Error: ", e.code
                else
                    @log.err bg-red "Other Socket Error: ", e

                @trigger \needReconnect, e.code

            ..on \end, ~>
                @log.log "socket end!"
                @trigger \needReconnect

    login: (credentials, callback) ->
        @off \relogin
        @on \relogin, (opts) ~>
            @log.log "sending credentials..."
            err, res <~ @auth.login credentials
            if opts?.forget-password
                #@log.warn "forgetting password"
                credentials := token: try
                    res.auth.session.token
                catch
                    null

            callback err, res

        if @connected
            @trigger \relogin, {forget-password: @opts.forget-password}

    logout: (callback) ->
        @auth.logout callback
