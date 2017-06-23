require! './actor': {Actor}
create-hash = require 'sha.js'
require! 'prelude-ls': {find}
require! uuid4

hash-passwd = (passwd) ->
    sha512 = create-hash \sha512
    sha512.update passwd, 'utf-8' .digest \hex

user-db =
    * _id: 'user1'
      passwd-hash: hash-passwd "hello world"

    * _id: 'user2'
      passwd-hash: hash-passwd "hello world2"

session-db = []

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
            data: (msg) ~>
                @network-send msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"
                @online-counter--

        # socket behaviours
        @socket.on \disconnect, ~>
            #@log.log "Client disconnected, killing actor. "
            @kill \disconnect, 0

        @socket.on "aktos-message", (msg) ~>
            if \payload of msg
                @network-receive msg
            else if \auth of msg
                @log.log "this is an authentication message. "
                doc = find (._id is msg.auth.username), user-db

                if not doc
                    @log.err "user is not found"
                else
                    if doc.passwd-hash is hash-passwd msg.auth.password
                        @log.log "user logged in. hash: "
                        session =
                            _id: msg.auth.username
                            token: uuid4!
                            date: Date.now!

                        if find (.token is session.token), session-db
                            @log.err "********************************************************"
                            @log.err "*** BIG MISTAKE: TOKEN SHOULD NOT BE FOUND ON SESSION DB"
                            @log.err "********************************************************"

                        else
                            @log.log session.token
                            session-db.push session
                            @network-send @msg-template! <<<< do
                                sender: @actor-id
                                auth:
                                    session: session
                                topic: 'nothing'
                    else
                        @log.err "wrong password", doc, msg.auth.password


    action: ->
        @log.log "+---> New socket.io client (id: #{@socket.id}) connected, starting its forwarder..."

    network-receive: (msg) ->
        @log.section \debug-redirect, "redirecting msg from 'network' interface to 'local' interface"
        @send-enveloped msg

    network-send: (msg) ->
        try
            @log.section \debug-redirect, "redirecting msg from 'local' interface to 'network' interface"
            @socket.emit 'aktos-message', msg
        catch
            @kill "NETWORK_SEND_FAILED", e
