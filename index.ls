# Core
# ---------
require! './src/actor': {Actor}
require! './src/filters': {FpsExec}
require! './src/signal': {Signal, SignalBranch}

# Connectors
# ----------
# CouchDCS
require! './services/couch-dcs/client': {CouchDcsClient}
require! './services/couch-dcs/server': {CouchDcsServer}

# Dcs Proxy
require! './services/dcs-proxy/tcp/client': {DcsTcpClient}

require! './lib': {
    EventEmitter, Logger, sleep, merge
    pack, unpack, clone, diff
}

require! './src/topic-match': {topic-match}

require! './proxy-actors/io-proxy/io-proxy-client': {IoProxyClient}
require! './proxy-actors/io-proxy/io-proxy-handler': {IoProxyHandler}

require! './drivers/driver-abstract': {DriverAbstract}

module.exports = {
    Actor, FpsExec, Signal, SignalBranch
    CouchDcsClient, CouchDcsServer,
    DcsTcpClient
    EventEmitter, Logger, sleep, merge
    pack, unpack, clone, diff
    IoProxyClient, IoProxyHandler
    DriverAbstract
    topic-match
}
