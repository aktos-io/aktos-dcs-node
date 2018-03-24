# Core
# ---------
require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal}

# Connectors
# ----------
# CouchDCS
require! './connectors/couch-dcs/client': {CouchDcsClient}
require! './connectors/couch-dcs/server': {CouchDcsServer}
# TCP DCS
require! './connectors/tcp-dcs/server': {TcpDcsServer}
require! './connectors/tcp-dcs/client': {TcpDcsClient}

require! './protocol-actors/proxy/auth-db': {AuthDB}
require! './lib': {
    EventEmitter, Logger, sleep, merge
    pack, unpack, clone, diff
}

module.exports = {
    Actor, FpsExec, Signal
    CouchDcsClient, CouchDcsServer
    TcpDcsServer, TcpDcsClient
    AuthDB
    EventEmitter, Logger, sleep, merge
    pack, unpack, clone, diff
}
