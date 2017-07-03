require! './proxy-actor': {ProxyActor, unpack-telegrams}
require! './auth-handler': {AuthHandler}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}

export class ProxyAuthority extends ProxyActor
    (@socket, @opts) ->
        super!
        @role = \authority


        @auth = new AuthHandler @opts.db
        @auth.send-raw = (msg) ~>
            @socket.write pack msg

        @auth.on \login, (subscriptions) ~>
            topics = flatten (subscriptions.ro ++ subscriptions.rw)
            @log.log bg-blue "authentication successful, subscribing relevant topics: ", topics
            @subscribe topics

        # actor behaviours
        @on do
            receive: (msg) ~>
                #@log.log "received message from local interface:", pack msg
                @socket.write pack msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"

        # network interface events
        @socket.on \disconnect, ~>
            @log.log "Client disconnected."
            #@kill \disconnect, 0

        @socket.on "data", (data) ~>
            # in "client mode", authorization checks are disabled
            # message is only forwarded to manager
            for msg in unpack-telegrams data.to-string!
                if \auth of msg
                    @log.log green "received auth message: ", msg
                    @auth._inbox msg
                else
                    msg = @auth.filter-incoming msg
                    if msg
                        #@log.log "received data, forwarding to local manager: ", msg
                        @send-enveloped msg

        @socket.on \error, (e) ~>
            @log.log "proxy authority  has an error"

        @socket.on \end, ~>
            @log.log "proxy authority ended."
            @kill \disconnected

        @on \connected, ~>
            @log.log "««==»» New proxy connection established. name: #{@name}"
