require! './actor': {Actor}

export class SocketIOServer extends Actor
    (io) ->
        super 'SocketIO Server'
        @io = io
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
    (socket, opts) ->
        """
        SocketIO handler(s) are just simple forwarders between a socket.io client
        and the ActorManager.

        This handler simply forwards from `network` interface to `local`
        interface and vice versa.
        """
        @socket = socket
        super (opts.name or @socket.id)
        @subscribe '**'

        @online-counter = opts.counter
        @log.sections ++= [
            #\debug-kill
            #\debug-redirect
        ]

        # actor behaviours
        @on-receive (msg) ~>
            @network-send msg

        @on-kill (reason, e) ->
            @log.log "Killing actor. Reason: #{reason}"
            @online-counter--

        # socket behaviours
        @socket.on \disconnect, ~>
            #@log.log "Client disconnected, killing actor. "
            @kill \disconnect, 0

        @socket.on "aktos-message", (msg) ~>
            @network-receive msg

    action: ->
        @log.log "+---> New socket.io client (id: #{@socket.id}) connected, starting its forwarder..."

    network-receive: (msg) ->
        @log.section \debug-redirect, "redirecting msg from 'network' interface to 'local' interface"
        @send_raw msg

    network-send: (msg) ->
        try
            @log.section \debug-redirect, "redirecting msg from 'local' interface to 'network' interface"
            @socket.emit 'aktos-message', msg
        catch
            @kill "NETWORK_SEND_FAILED", e
