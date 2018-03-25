require! './helpers': {MessageBinder}
require! '../../src/auth-handler': {AuthHandler}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! '../../lib': {pack}
require! 'prelude-ls': {split, flatten, split-at}
require! '../../src/actor': {Actor}


export class ProxyHandler extends Actor
    (@transport, opts) ->
        """
        opts:
            name: name
            creator: parent object
            db: auth-db instance
        """
        super opts.name
        @subscribe "public.**"
        @log.log ">>=== New connection from the client is accepted. name: #{@name}"

        @data-binder = new MessageBinder!
        @auth = new AuthHandler opts.db
            ..on \to-client, (msg) ~>
                @transport.write pack @msg-template msg

            ..on \login, (subscriptions) ~>
                @log.log bg-blue "subscribing readonly: ", subscriptions.ro
                @subscribe subscriptions.ro
                @log.log bg-yellow "subscribing read/write: ", subscriptions.rw
                @subscribe subscriptions.rw

            ..on \logout, ~>
                # remove all subscriptions
                @subscriptions = []

        # DCS interface
        @on do
            receive: (msg) ~>
                #@log.log "received message from local interface:", pack msg
                @transport.write pack msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"

        # transport interface
        @transport
            ..on "data", (data) ~>
                # in "client mode", authorization checks are disabled
                # message is only forwarded to manager
                for msg in @data-binder.get-messages data
                    if \auth of msg
                        #@log.log green "received auth message: ", msg
                        @auth.trigger \check-auth, msg
                    else
                        #@log.log "received normal message:", msg
                        try
                            msg
                            |> @auth.check-permissions
                            #|> (x) -> console.log "checked permissions", x; return x
                            |> @send-enveloped

                            #@log.log "forwarding to DCS network..."

            ..on \disconnect, ~>
                @log.log "proxy handler is exiting."
                @kill \disconnected
