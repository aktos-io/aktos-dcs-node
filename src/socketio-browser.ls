require! './actor': {Actor}
require! 'aea/debug-log': {debug-levels}
require! 'prelude-ls': {
    initial,
    drop,
    join,
    split,
}

/*

SocketIOBrowser has two "network interfaces":

    1. ActorManager (as every Actor has)
    2. network

SocketIOBrowser simply forwards all messages it receives to/from ActorManager
from/to network and is also responsible from security.

*/

export class SocketIOBrowser extends Actor
    @instance = null
    (opts) ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this

        super \SocketIOBrowser
        @subscribe '**'

        @token = null
        @connection-listener = (self, connect-str) ->

        addr = opts.address
        path = "#{opts.path or '/'}socket.io"
        #@log.log "Connecting to #{addr} path: #{path}"
        @socket = io.connect addr, path: path

        @on do
            'network-receive': (msg) ~>
                # receive from server via socket.io
                # forward message to inner actors
                @log.section \debug-network, "proxy actor got network message: ", msg
                unless \auth of msg
                    @send-enveloped msg

            'receive': (msg) ~>
                @log.section \debug-local, "received msg: ", msg
                @network-send-raw msg


        @socket.on do
            'aktos-message': (msg) ~>
                @trigger \network-receive, msg

            "connect": !~>
                @log.section \v1, "Connected to server with id: ", @socket.io.engine.id

            "disconnect": !~>
                @log.section \v1, "proxy actor says: disconnected"


    network-send: (msg) ->
        @log.section \debug-network, "network-send msg: ", msg
        @network-send-raw @msg-template <<<< do
            payload: msg

    network-send-raw: (msg) ->
        # receive from inner actors, forward to server
        #
        # ---------------------------------------------------------
        # WARNING:
        # ---------------------------------------------------------
        # Do not modify msg.sender. Since it's only a reference to the original message,
        # modifying this object will cause the original message to be
        # sent back to it's original sender (which is an error)
        # ---------------------------------------------------------

        msg.token = @token
        @socket.emit 'aktos-message', msg
