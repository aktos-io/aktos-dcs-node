require! './actor': {Actor}
require! './socketio-helpers': {Wrapper}
require! './proxy-client': {ProxyClient}

export class SocketIOBrowser extends Actor
    (opts) ->
        super \SocketIOBrowser

        addr = opts.address
        path = "#{opts.path or '/'}socket.io"
        #@log.log "Connecting to #{addr} path: #{path}"
        socket = io.connect addr, path: path

        @proxy = new ProxyClient (new Wrapper socket), do
            name: \client-proxy
            creator: this
            forget-password: yes

        @proxy.on \connected, ~>
            @log.log "Connected to server with id: ", socket.io.engine.id

        @proxy.on \needReconnect, ~>
            @log.log "proxy needs reconnection but socket.io will handle this. nothing to do here."
