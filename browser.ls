require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal}
require! './connectors/socketio/browser': {SocketIOBrowser}
require! './connectors/couch-dcs/client': {CouchDcsClient}
require! './src/topic-match': {topic-match}

module.exports = {
    Actor
    Signal
    SocketIOBrowser
    CouchDcsClient
    topic-match
    FpsExec
}
