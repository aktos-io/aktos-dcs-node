require! './src/actor': {Actor}
require! './src/io-actor': {IoActor}
require! './src/socketio-browser': {SocketIOBrowser}
require! './src/signal': {Signal}
require! './src/find-actor': {find-actor}

module.exports = {
    IoActor, SocketIOBrowser, Signal, Actor
    find-actor
}
