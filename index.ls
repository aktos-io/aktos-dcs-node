require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal}
require! './connectors/socketio/server': {SocketIOServer}
require! './connectors/tcp/client': {TCPProxyClient}
require! './connectors/tcp/server': {TCPProxyServer}
require! './connectors/couch-dcs/client': {CouchDcsClient}
require! './connectors/couch-dcs/server': {CouchDcsServer}

module.exports = {
    Actor, SocketIOServer, TCPProxyClient, TCPProxyServer,
    CouchDcsClient, CouchDcsServer
    FpsExec, Signal
}
