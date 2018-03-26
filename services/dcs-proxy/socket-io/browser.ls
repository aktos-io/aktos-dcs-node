require! 'dcs/transports/socket-io': {SocketIOTransport}
require! '../protocol-actor/client': {ProxyClient}

export class DcsSocketIOBrowser extends ProxyClient
    (opts) ->
        addr = opts.address
        path = "#{opts.path or '/'}socket.io"
        #@log.log "Connecting to #{addr} path: #{path}"
        socket = io.connect addr, path: path
        transport = new SocketIOTransport socket

        super transport, do
            name: \SocketIOBrowser
            forget-password: yes

        @on \connected, ~>
            @log.log "Info: Connected to server with id: ", socket.io.engine.id

        @on \disconnect, ~>
            @log.log "Info: Disconnected."
