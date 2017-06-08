require! './actor': {Actor}

class SocketIOHandler extends Actor
    (socket) ->
        """
        SocketIO handler(s) are just simple forwarders between a socket.io client
        and the ActorManager.

        This handler simply forwards from `network` interface to `local`
        interface and vice versa.
        """
        @socket = socket
        super @socket.id

        @log.sections ++= [
            #\debug-kill
            #\debug-redirect
        ]

        @on-receive (msg) ~>
            @network-send msg

        @on-kill ->
            @socket.end!
            @socket.destroy 'KILLED'

        # socket actions
        @socket.on \disconnect, ~>
            @log.log "TODO: decrase total user count!"
            @kill!


        @socket.on "aktos-message", (msg) ~>
            @log.log "aktos-message from browser: ", msg

            @network-receive msg

    action: ->
        @log.log "+---> New socket.io client (id: #{@socket.id}) connected, starting its forwarder..."

    network-receive: (msg) ->
        @log.section \debug-redirect, "redirecting msg from 'network' interface to 'local' interface"
        @send_raw msg

    network-send: (data) ->
        try
            @log.section \debug-redirect, "redirecting msg from 'local' interface to 'network' interface"
            @socket.emit 'aktos-message', msg
        catch
            @kill "NETWORK_SEND_FAILED"

export class SocketIOServer extends Actor
    (io) ->
        super 'SocketIO Server'
        @io = io
        @connected-user-count = 0

        @io.on 'connection', (socket) ~>
            # launch a new handler 
            new SocketIOHandler socket

            # track online users
            @connected-user-count++
            @log.log "Total online user count: #{@connected-user-count}"

    action: ->
        @log.log "SocketIO server started..."
