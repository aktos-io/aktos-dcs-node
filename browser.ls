require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal}
require! './services/dcs-proxy/socket-io/browser': {DcsSocketIOBrowser}
require! './services/couch-dcs/client': {CouchDcsClient}
require! './src/topic-match': {topic-match}

# NodeJS components
require! './services/dcs-proxy/socket-io/server': {DcsSocketIOServer}

module.exports = {
    Actor
    Signal
    DcsSocketIOBrowser
    DcsSocketIOServer
    CouchDcsClient
    topic-match
    FpsExec
}
