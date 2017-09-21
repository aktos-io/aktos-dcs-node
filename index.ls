require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal}
require! './connectors/tcp/client': {TCPProxyClient}
require! './connectors/tcp/server': {TCPProxyServer}
require! './connectors/couch-dcs/client': {CouchDcsClient}
require! './connectors/couch-dcs/server': {CouchDcsServer}
require! './proxy/auth-db': {AuthDB}
require! './lib': {EventEmitter, Logger, sleep}

module.exports = {
    Actor, TCPProxyClient, TCPProxyServer,
    CouchDcsClient, CouchDcsServer
    FpsExec, Signal
    AuthDB
    EventEmitter, Logger, sleep 
}
