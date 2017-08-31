require! './proxy-actor': {ProxyActor, MessageBinder}
require! './auth-handler': {AuthHandler}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}



export class ProxyAuthority extends ProxyActor
    (@socket, @opts) ->
        super!
        @role = \authority

        @log.log ">>=== New connection from the client is accepted. name: #{@name}"

        @data-binder = new MessageBinder!
        @auth = new AuthHandler @opts.db
        @auth.send-raw = (msg) ~>
            @socket.write pack msg

        @subscribe "public.**"
        @auth.on \login, (subscriptions) ~>
            topics = flatten (subscriptions.ro ++ subscriptions.rw)
            @log.log bg-blue "authentication successful, subscribing relevant topics: ", topics
            @subscribe topics

        @auth.on \logout, ~>
            # remove all subscriptions
            @mgr.unsubscribe this

        # actor behaviours
        @on do
            receive: (msg) ~>
                #@log.log "received message from local interface:", pack msg
                @socket.write pack msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"


        # network interface events
        @socket.on "data", (data) ~>
            # in "client mode", authorization checks are disabled
            # message is only forwarded to manager
            for msg in @data-binder.get-messages data
                if \auth of msg
                    #@log.log green "received auth message: ", msg
                    @auth.trigger \receive, msg
                else
                    msg = @auth.filter-incoming msg
                    if msg
                        #@log.log "received data, forwarding to local manager: ", msg
                        @send-enveloped msg

        @socket.on \end, ~>
            @log.log "proxy authority ended."
            @kill \disconnected

        # -------------------------------------------------------------
        #    unhandled events (no action taken). do we need them?
        # -------------------------------------------------------------
        @socket.on \error, (e) ~>
            @log.log bg-red "UNHANDLED EVENT: proxy authority  has an error"

        @socket.on \disconnect, ~>
            @log.log bg-red "UNHANDLED EVENT: Client disconnected."
