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
            @log.log "requesting update messages for subscribed topics"
            for topic in topics
                @auth.send-with-token @msg-template do
                    topic: topic
                    update: yes

        @on do
            receive: (msg) ~>
                #@log.log "forwarding message #{msg.topic} to network interface"
                if @socket-ready
                    @auth.send-with-token msg
                else
                    @log.log bg-yellow "Socket not ready, not sending message: "
                    console.log "msg is: ", msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"
                @socket.end!
                @socket.destroy 'KILLED'

            needReconnect: ~>
                @socket-ready = no

            connected: ~>
                @log.log "<===> New proxy connection established. name: #{@name}"
                @socket-ready = yes
                @trigger \relogin # triggering procedures on (re)login


        # ----------------------------------------------
        #            network interface events
        # ----------------------------------------------
        @socket.on \connect, ~>
            @trigger \connected

        @socket.on \disconnect, ~>
            @log.log "Client disconnected."

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

            @trigger \needReconnect, e.code

        @socket.on \end, ~>
            @log.log "socket end!"
            @trigger \needReconnect

    login: (credentials, callback) ->
        @event-handlers['relogin'] = []
        @on \relogin, ~>
            err, res <~ @auth.login credentials
            callback err, res
        @trigger \relogin

    logout: (callback) ->
        @auth.logout callback
