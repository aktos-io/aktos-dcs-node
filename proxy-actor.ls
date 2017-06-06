require! './core': {Actor, envelp}
require! 'prelude-ls': {
    initial,
    drop,
    join,
    split,
}

/*

ProxyActor has two "network interfaces":

    1. ActorManager (as every Actor has)
    2. network

ProxyActor simply forwards all messages it receives to/from ActorManager
from/to network.

ProxyActor is also responsible from security.

*/

class _ProxyActor extends Actor
    ->
        __ = @
        super \ProxyActor
        #console.log "Proxy actor is created with id: ", @actor-id

        @token = null
        @connection-listener = (self, connect-str) ->

        # calculate socket.io path
        # -----------------------------------------------------------
        /* initialize socket.io connections */
        url = String window.location .split '#' .0
        arr = url.split "/"
        addr_port = arr.0 + "//" + arr.2
        socketio-path = [''] ++ (initial (drop 3, arr)) ++ ['socket.io']
        socketio-path = join '/' socketio-path
        @log.log "socket-io path: #{socketio-path}, url: #{url}"
        # FIXME: HARDCODED SOCKET.IO PATH
        socketio-path = "/socket.io"

        @socket = io.connect do
            port: addr_port
            path: socketio-path

        # send to server via socket.io
        @socket.on 'aktos-message', (msg) ~> @network-receive msg

        @socket.on "connect", !~>
            @log.log "Connected to server with id: ", __.socket.io.engine.id

        @socket.on "disconnect", !~>
            @log.log "proxy actor says: disconnected"

    update-io: ->
        @network-send UpdateIoMessage: {}

    network-receive: (msg) ->
        # receive from server via socket.io
        # forward message to inner actors
        @log.debug-log "proxy actor got network message: ", msg
        @send_raw msg

    receive: (msg) ->
        @log.debug-log "received msg: ", msg
        @network-send-raw msg


    network-send: (msg) ->
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


export class ProxyActor
    instance = null
    ->
        instance ?:= new _ProxyActor!
        return instance
