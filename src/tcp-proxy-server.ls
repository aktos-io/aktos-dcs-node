require! 'net'
require! './actor': {Actor}
require! 'colors': {yellow, green, red, blue}
require! 'aea': {sleep, hex, ip-to-hex}
require! 'prelude-ls': {drop, reverse}
require! './proxy-authority':{ProxyAuthority}


export class TCPProxyServer extends Actor
    (@opts={}) ->
        super \TCPProxyServer
        @server = null
        @port = if @opts.port => that else 5523
        @server-retry-period = 2000ms

        @server = net.create-server (socket) ~>
            name = "H#{ip-to-hex (drop 7, socket.remoteAddress)}:#{hex socket.remotePort}"

            proxy = new ProxyAuthority socket, do
                name: name
                creator: this
                db: @opts.db

            proxy.on \kill, (reason) ~>
                @log.log "Creator says proxy actor (authority) (#{proxy.id}) just died!"

        @server.on \error, (e) ~>
            if e.code is 'EADDRINUSE'
                @log.warn "Address in use, retrying in #{@server-retry-period}ms"
                @run-client!
                <~ sleep @server-retry-period
                @server.close!
                @_start!

        @server.listen @port, ~>
            @log.log "Broker started in #{green "server mode"} on port #{@port}."
