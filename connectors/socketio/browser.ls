require! '../../src/actor': {Actor}
require! './helpers': {Wrapper}
require! '../../proxy/client': {ProxyClient}

export class SocketIOBrowser extends ProxyClient
    (opts) ->
        addr = opts.address
        path = "#{opts.path or '/'}socket.io"
        #@log.log "Connecting to #{addr} path: #{path}"
        socket = io.connect addr, path: path

        super (new Wrapper socket), do
            name: \SocketIOBrowser
            creator: this
            forget-password: yes

        @on \connected, ~>
            @log.log "Connected to server with id: ", socket.io.engine.id

        @on \needReconnect, ~>
            @log.log "proxy needs reconnection but socket.io will handle this. nothing to do here."
