require! 'net'
require! './actor': {Actor}
require! 'aea': {sleep}

class BrokerActor extends Actor
    (socket) ->
        super!
        @socket = socket
        @log.log "Device connected: ", @socket

        @socket.write "Hello world!"

        @socket.on \data, (data) ~>
            packet = data.to-string!
            @log.log "data received: ", packet

class Broker extends Actor
    ->
        super ...
        @server = null
        @create-server!

    create-server: ->
        @server = net.create-server (socket) ->
            new HostlinkActor socket

        @server.listen 5523, '0.0.0.0', ~>
            @log.log "Broker started listening..."

new Broker!
