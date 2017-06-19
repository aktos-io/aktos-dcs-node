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

        __ = @
        super \SocketIOBrowser

        @token = null
        @connection-listener = (self, connect-str) ->

        addr = opts.address
        path = "#{opts.path or '/'}socket.io"
        @log.log "SocketIOBrowser is connecting to #{addr} path: #{path}"
        @socket = io.connect addr, path: path

        # send to server via socket.io
        @socket.on 'aktos-message', (msg) ~>
            @network-receive msg

        @socket.on "connect", !~>
            @log.section \v1, "Connected to server with id: ", __.socket.io.engine.id

        @socket.on "disconnect", !~>
            @log.section \v1, "proxy actor says: disconnected"

        @on-receive (msg) ~>
            @log.section \debug-local, "received msg: ", msg
            @network-send-raw msg



    update-io: ->
        @network-send UpdateIoMessage: {}

    network-receive: (msg) ->
        # receive from server via socket.io
        # forward message to inner actors
        @log.section \debug-network, "proxy actor got network message: ", msg
        @send_raw msg

    network-send: (msg) ->
        @log.section \debug-network, "network-send msg: ", msg
        @network-send-raw (envelp msg, @get-msg-id!)

    network-send-raw: (msg) ->
        # receive from inner actors, forward to server
        #
        # ---------------------------------------------------------
        # WARNING:
        # ---------------------------------------------------------
        # Do not modify msg as it's only a reference to original message,
        # so modifying this object will cause the original message to be
        # sent to it's original source (which is an error)
        # ---------------------------------------------------------

        msg.token = @token
        @socket.emit 'aktos-message', msg
