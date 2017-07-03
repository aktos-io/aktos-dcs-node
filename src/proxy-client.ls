require! './proxy-actor': {ProxyActor, unpack-telegrams}
require! './auth-request': {AuthRequest}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}
require! './signal':{Signal}

export class ProxyClient extends ProxyActor
    (@socket, @opts) ->
        super!
        # actor behaviours
        @role = \client

        @auth = new AuthRequest!
        @auth.send-raw = (msg) ~>
            @socket.write pack msg

        @auth.on \login, (permissions) ~>
            topics = permissions.rw
            @log.log "logged in succesfully. subscribing to: ", topics
            @subscribe topics

        @on do
            receive: (msg) ~>
                #@log.log "forwarding message to network interface"
                if @socket-ready
                    @auth.send-with-token msg
                else
                    @log.log bg-yellow "Socket not ready, not sending message..."

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"
                @socket.end!
                @socket.destroy 'KILLED'

            reconnect: ~>
                @socket-ready = no


        @login-signal = new Signal!
        # network interface events
        @socket.on \disconnect, ~>
            @log.log "Client disconnected."
            #@kill \disconnect, 0

        @socket.on "data", (data) ~>
            # in "client mode", authorization checks are disabled
            # message is only forwarded to manager
            for msg in unpack-telegrams data.to-string!
                if \auth of msg
                    @log.log "received auth message, forwarding to AuthRequest."
                    @auth.inbox msg
                else
                    #@log.log "received data: ", msg
                    @send-enveloped msg

        @socket.on \error, (e) ~>
            if e.code in <[ EPIPE ECONNREFUSED ECONNRESET ETIMEDOUT ]>
                @log.err red "Socket Error: ", e.code
            else
                @log.err bg-red "Other Socket Error: ", e

            @trigger \reconnect, e.code

        @socket.on \end, ~>
            @log.log "socket end!"
            @trigger \reconnect

        @on \connected, ~>
            @log.log "Proxy knows that it is connected."
            @log.log "+---> New proxy connection established. name: #{@name}, role: #{@role}"
            @socket-ready = yes
            reason, credentials <~ @login-signal.wait
            err, res <~ @auth.login credentials
            @log.log "there is error: ", err if err
            @log.log "authorization finished: ", res

    login: (credentials) ->
        @login-signal.go {username: "user1", password: "hello world"}
