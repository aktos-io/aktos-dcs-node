require! './src/actor': {Actor}
require! './src/io-actor': {IoActor}
require! './src/socketio-browser': {SocketIOBrowser}
require! './src/signal': {Signal}
require! './src/auth-actor': {AuthActor}

module.exports = {
    IoActor, SocketIOBrowser, Signal, Actor, AuthActor
}
