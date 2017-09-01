require! './src/actor': {Actor}
require! './src/socketio-server': {SocketIOServer}
require! './src/tcp-proxy-client': {TCPProxyClient}
require! './src/tcp-proxy-server': {TCPProxyServer}
require! './src/couch-dcs/couch-dcs-client': {CouchDcsClient}
require! './src/couch-dcs/couch-dcs-server': {CouchDcsServer}

module.exports = {
    Actor, SocketIOServer, TCPProxyClient, TCPProxyServer,
    CouchDcsClient, CouchDcsServer
}
