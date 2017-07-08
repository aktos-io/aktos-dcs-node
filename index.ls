require! './src/actor': {Actor}
require! './src/socketio-server': {SocketIOServer}
require! './src/tcp-proxy': {TCPProxy}
require! './src/couch-proxy': {CouchProxy}

module.exports = {
    Actor, SocketIOServer, TCPProxy, CouchProxy
}
