require! './src/actor': {Actor}
require! './src/socketio-server': {SocketIOServer}
require! './src/tcp-proxy-client': {TCPProxyClient}
require! './src/tcp-proxy-server': {TCPProxyServer}
require! './src/couch-proxy': {CouchProxy}

module.exports = {
    Actor, SocketIOServer, TCPProxyClient, TCPProxyServer, CouchProxy
}
