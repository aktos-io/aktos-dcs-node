# Core
require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal}

# Connectors
# TCP
require! './connectors/tcp/client': {TCPProxyClient}
require! './connectors/tcp/server': {TCPProxyServer}
# CouchDCS
require! './connectors/couch-dcs/client': {CouchDcsClient}
require! './connectors/couch-dcs/server': {CouchDcsServer}
# TCP DCS
require! './connectors/tcp-dcs/server': {TcpDcsServer}
require! './connectors/tcp-dcs/client': {TcpDcsClient}

require! './proxy/auth-db': {AuthDB}
require! './lib': {EventEmitter, Logger, sleep, merge}

module.exports = {
    Actor, TCPProxyClient, TCPProxyServer,
    CouchDcsClient, CouchDcsServer
    FpsExec, Signal
    AuthDB
    EventEmitter, Logger, sleep, merge
    TcpDcsServer, TcpDcsClient
}
