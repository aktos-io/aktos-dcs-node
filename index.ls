require! './src/actor': {Actor}
require! './src/socketio-server': {SocketIOServer}
require! './src/tcp-proxy': {TCPProxy}

module.exports = {
    Actor, SocketIOServer, TCPProxy,
}
