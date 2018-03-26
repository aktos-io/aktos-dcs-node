require! '../deps': {AuthHandler, pack, unpack, Actor}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'prelude-ls': {split, flatten, split-at}
require! './helpers': {MessageBinder}


export class ProxyHandler extends Actor
    (@transport, opts) ->
        """
        opts:
            name: name
            db: auth-db instance
        """
        super opts.name
        @subscribe "public.**"
        @log.log ">>=== New connection from the client is accepted. name: #{@name}"

        @auth = new AuthHandler opts.db, opts.name
            ..on \to-client, (msg) ~>
                @transport.write pack @msg-template msg

            ..on \login, (subscriptions) ~>
                if subscriptions.ro
                    @log.log bg-blue "subscribing readonly: ", that
                    @subscribe that

                if subscriptions.rw
                    @log.log bg-yellow "subscribing read/write: ", that
                    @subscribe that

            ..on \logout, ~>
                # remove all subscriptions
                @subscriptions = []

        # DCS interface
        @on do
            receive: (msg) ~>
                @log.log "            DCS > Transport: (topic : #{msg.topic})"
                @transport.write pack msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"

        # transport interface
        @m = new MessageBinder!
        @transport
            ..on "data", (data) ~>
                for msg in @m.append data
                    # in "client mode", authorization checks are disabled
                    # message is only forwarded to manager
                    if \auth of msg
                        #@log.log green "received auth message: ", msg
                        @auth.trigger \check-auth, msg
                    else
                        @log.log "Transport > DCS (topic: #{msg.topic})"
                        try
                            msg
                            |> @auth.check-permissions
                            #|> (x) -> console.log "checked permissions", x; return x
                            |> @send-enveloped

                            #@log.log "forwarding to DCS network...", data.to-string!

            ..on \disconnect, ~>
                @log.log "proxy handler is exiting."
                @kill \disconnected
