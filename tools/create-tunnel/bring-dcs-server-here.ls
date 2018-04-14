require! './': {bind-server-to-local}
require! 'dcs': {sleep}

#args = process.argv.slice(2)
dcs-port = process.argv.2 or 5588

config = 
    server-port: dcs-port
    local-port: dcs-port


pfx = "server:#{config.server-port} -> localhost:#{config.local-port}"
console.log "Starting creating tunnel #{pfx}"
<~ :lo(op) ~> 
    err <~ bind-server-to-local config
    unless err 
        console.log "#{pfx} Tunnel is created successfully (will renew in 30 sec. just in case)"
        <~ sleep 30_000ms
        lo(op)
    else 
        console.error "#{pfx} Tunnel is failed, retry in 5 seconds..."
        <~ sleep 5_000ms 
        lo(op)
