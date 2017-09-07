require! './proxy-actor': {ProxyActor, MessageBinder}
require! './auth-handler': {AuthHandler}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}



export class ProxyAuthority extends ProxyActor
    (@socket, opts) ->
        """
        opts:
            name: name
            creator: parent object
            db: auth-db instance
        """
        super opts.name

        @role = \authority

        @log.log ">>=== New connection from the client is accepted. name: #{@name}"

        @data-binder = new MessageBinder!
        @auth = new AuthHandler opts.db
        @auth.send-raw = (msg) ~>
            @socket.write pack msg

        @subscribe "public.**"
        @auth.on \login, (subscriptions) ~>
            @log.log bg-blue "subscribing readonly: ", subscriptions.ro
            @subscribe subscriptions.ro
            @log.log bg-yellow "subscribing read/write: ", subscriptions.rw
            @subscribe subscriptions.rw

        @auth.on \logout, ~>
            # remove all subscriptions
            @subscriptions = []

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
            @log.log bg-red "UNHANDLED EVENT: proxy authority  has an error", e

        @socket.on \disconnect, ~>
            @log.log bg-red "UNHANDLED EVENT: Client disconnected."
