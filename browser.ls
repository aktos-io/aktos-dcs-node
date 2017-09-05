require! './src/actor': {Actor}
require! './src/io-actor': {IoActor}
require! './src/socketio-browser': {SocketIOBrowser}
require! './src/signal': {Signal}
require! './src/find-actor': {find-actor}
require! './src/couch-dcs/couch-dcs-client': {CouchDcsClient}
require! './src/topic-match': {topic-match}
require! './src/filters': {FpsExec}
require! './src/ractive-actor': {RactiveActor}

module.exports = {
    IoActor, SocketIOBrowser, Signal, Actor
    find-actor, CouchDcsClient
    topic-match
    FpsExec
    RactiveActor
}
