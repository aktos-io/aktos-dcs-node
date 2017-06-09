require! './actor': {Actor}

class SocketIOHandler extends Actor
    (socket, name) ->
        """
        SocketIO handler(s) are just simple forwarders between a socket.io client
        and the ActorManager.

        This handler simply forwards from `network` interface to `local`
        interface and vice versa.
        """
        @socket = socket
        super (name or @socket.id)

        @log.sections ++= [
            #\debug-kill
            #\debug-redirect
        ]

        # actor behaviours
        @on-receive (msg) ~>
            @network-send msg

        @on-kill (reason, e) ->
            @log.log "Killing actor: #{reason}", e
            @log.log "TODO: decrase total user count!"

        # socket behaviours
        @socket.on \disconnect, ~>
            @log.log "Client disconnected, killing actor. "
            @kill!

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

export class SocketIOServer extends Actor
    (io) ->
        super 'SocketIO Server'
        @io = io
        @connected-user-count = 0
        @handler-counter = 0

        @io.on 'connection', (socket) ~>
            # launch a new handler
            new SocketIOHandler socket, "socketio-#{++@handler-counter}"

            # track online users
            @connected-user-count++
            @log.log "Total online user count: #{@connected-user-count}"

    action: ->
        @log.log "SocketIO server started..."
