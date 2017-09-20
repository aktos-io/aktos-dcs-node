require! 'net'
require! 'dcs': {Actor}
require! './hostlink-actor': {HostlinkActor}


export class HostlinkTcpServer extends Actor
    (opts) ->
        super \HostlinkTcpServer
        @port = opts?.port or 2000
        @create-server!

    create-server: ->
        @server = net.create-server (socket) ->
            new HostlinkActor socket, do
                unit-no: 0
                subscriptions: 'public.**'

        @server.listen @port, '0.0.0.0', ~>
            @log.log "Hostlink Server started listening on port: #{@port}"
