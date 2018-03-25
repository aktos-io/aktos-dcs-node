require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal}
require! './connectors/socket-io/browser': {SocketIOBrowser}
require! './connectors/couch-dcs/client': {CouchDcsClient}
require! './src/topic-match': {topic-match}

# NodeJS components
require! './connectors/socket-io/server': {SocketIOServer}

module.exports = {
    Actor
    Signal
    SocketIOBrowser
    SocketIOServer
    CouchDcsClient
    topic-match
    FpsExec
}
