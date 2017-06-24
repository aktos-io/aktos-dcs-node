require! './actor': {Actor}
require! 'prelude-ls': {find}
require! 'aea': {sleep}

export class SocketIOServer extends Actor
    (@io) ->
        super 'SocketIO Server'
        @connected-user-count = 0
        @handler-counter = 0

        @io.on 'connection', (socket) ~>
            # track online users
            @connected-user-count++

            # launch a new handler
            new SocketIOHandler socket, do
                name: "socketio-#{++@handler-counter}"
                counter: @connected-user-count

    action: ->
        @log.log "SocketIO server started..."

class SocketIOHandler extends Actor
    (@socket, opts) ->
        """
        SocketIO handler(s) are just simple forwarders between a socket.io client
        and the ActorManager.

        This handler simply forwards from `network` interface to `local`
        interface and vice versa.
        """
        super (opts.name or @socket.id)
        @subscribe '**'

        @online-counter = opts.counter
        @log.sections ++= [
            #\debug-kill
            #\debug-redirect
        ]

        # actor behaviours
        @on do
            receive: (msg) ~>
                @network-send msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"
                @online-counter--

        # socket behaviours
        @socket.on \disconnect, ~>
            #@log.log "Client disconnected, killing actor. "
            @kill \disconnect, 0

        @socket.on "aktos-message", (msg) ~>
            @send-enveloped msg

    action: ->
        @log.log "+---> New socket.io client (id: #{@socket.id}) connected, starting its forwarder..."

    network-send: (msg) ->
        try
            @log.section \debug-redirect, "redirecting msg from 'local' interface to 'network' interface"
            @socket.emit 'aktos-message', msg
        catch
            @kill "NETWORK_SEND_FAILED", e
