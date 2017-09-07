require! 'net'
require! './actor': {Actor}
require! 'colors': {yellow, green, red, blue}
require! 'aea': {sleep, hex, ip-to-hex}
require! 'prelude-ls': {drop, reverse}
require! './proxy-authority':{ProxyAuthority}


export class TCPProxyServer extends Actor
    (opts={}) ->
        """
        opts:
            db: auth-db object
            port: dcs port
        """
        super \TCPProxyServer
        @server = null
        @port = if opts.port => that else 5523

        @server = net.create-server (socket) ~>
            name = "H#{ip-to-hex (drop 7, socket.remoteAddress)}:#{hex socket.remotePort}"

            proxy = new ProxyAuthority socket, do
                name: name
                creator: this
                db: opts.db

            proxy.on \kill, (reason) ~>
                @log.log "Creator says proxy actor (authority) (#{proxy.id}) just died!"

        @server.on \error, (e) ~>
            if e.code is 'EADDRINUSE'
                @log.warn "Address in use, giving up."
                @server.close!

        @server.listen @port, ~>
            @log.log "TCP Proxy Server started on port #{@port}."
