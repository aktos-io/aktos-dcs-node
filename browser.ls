require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal, SignalBranch}
require! './services/dcs-proxy/socket-io/browser': {DcsSocketIOBrowser}
require! './services/couch-dcs/client': {CouchDcsClient}
require! './src/topic-match': {topic-match}

global.dcs = module.exports = {
    Actor
    Signal, SignalBranch
    DcsSocketIOBrowser
    CouchDcsClient
    topic-match
    FpsExec
}
