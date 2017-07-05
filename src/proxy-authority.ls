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

            connected: ~>
                @log.log "««==»» New proxy connection established. name: #{@name}"

        # network interface events
        i = 0
        cache = ""
        @socket.on "data", (data) ~>
            # in "client mode", authorization checks are disabled
            # message is only forwarded to manager
            if typeof! data is \Uint8Array
                data = data.to-string!
            #@log.log "got message from network interface: ", data, (typeof! data)

            cache += data
            if 1 < i < 10
                @log.err bg-yellow "trying to cache more... (i = #{i})"
            else if i > 10
                @log.err bg-red "Problem while caching: "
                i := 0
                cache := ""
            i++
            res = try
                x = unpack-telegrams cache
                cache := ""
                i := 0
                x
            catch
                @log.err bg-red "Problem while unpacking data, trying to cache.", e
                []


            for msg in res
                if \auth of msg
                    #@log.log green "received auth message: ", msg
                    @auth._inbox msg
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
