require! './proxy-actor': {ProxyActor, MessageBinder}
require! './auth-request': {AuthRequest}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}
require! './signal':{Signal}

export class ProxyClient extends ProxyActor
    (@socket, @opts) ->
        super \ProxyClient
        # actor behaviours
        @role = \client

        @data-binder = new MessageBinder!

        @auth = new AuthRequest!
        @auth.send-raw = (msg) ~>
            @socket.write pack msg

        @auth.on \login, (permissions) ~>
            topics = permissions.rw
            @log.log "logged in succesfully. subscribing to: ", topics
            @subscribe topics

        @on do
            receive: (msg) ~>
                #@log.log "forwarding message #{msg.topic} to network interface"
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

        # ----------------------------------------------
        #            network interface events
        # ----------------------------------------------
        @socket.on \connect, ~>
            @trigger \connected

        @socket.on \disconnect, ~>
            @log.log "Client disconnected."
            #@kill \disconnect, 0

        @socket.on "data", (data) ~>
            # in "client mode", authorization checks are disabled
            # message is only forwarded to manager
            for msg in @data-binder.get-messages data 
                if \auth of msg
                    #@log.log "received auth message, forwarding to AuthRequest."
                    @auth.inbox msg
                else
                    #@log.log "received data: ", pack msg
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
            @log.log "<===> New proxy connection established. name: #{@name}"
            @socket-ready = yes
            @trigger \relogin # triggering procedures on (re)login

    login: (credentials, callback) ->
        @on \relogin, ~>
            err, res <~ @auth.login credentials
            callback err, res

        @trigger \relogin

    logout: (callback) ->
        @auth.logout callback
