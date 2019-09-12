require! './io-proxy-handler': {IoProxyHandler}
require! './io-proxy-client': {IoProxyClient}
require! './create-io-proxies': {create-io-proxies}
require! '../../lib/memory-map': {IoHandle}

module.exports = {
    IoProxyHandler
    IoProxyClient
    create-io-proxies
    IoHandle
}
