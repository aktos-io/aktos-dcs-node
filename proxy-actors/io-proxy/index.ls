require! '../../lib/memory-map': {MemoryMap}
require! './io-proxy-handler': {IoProxyHandler}
require! './io-proxy-client': {IoProxyClient}

create-io-proxies = (devices) ->
    for let device, service of devices
        console.log "========================> Initializing #{device}"
        for let handle in new MemoryMap service.handles .get-handles!
            #console.log "handle is: ", handle
            new IoProxyHandler handle, service.driver


module.exports = {
    MemoryMap
    IoProxyHandler
    IoProxyClient
    create-io-proxies
}
