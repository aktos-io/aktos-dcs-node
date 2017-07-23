require! 'child_process': {exec}

# create ssh tunnel

export create-proxy-server-tunnel = (opts, callback) ->
    mapping = if opts?
        that
    else
        local: 5588
        remote: 5599

    ssh = "ssh -S /tmp/ssh-mobmac2@aktos.io:443.sock example -N"
    console.log "Creating tunnel..."
    err, stdout, stderr <~ exec "#{ssh} -L #{mapping.local}:localhost:#{mapping.remote}"
    if err => return console.log "Port mapping failed."
    console.log "Tunnel is created: #{stdout}, #{stderr}"
    if typeof! callback is \Function
        callback err, stdout, stderr


if require.main is module
    console.log "directly called."
    err <- create-proxy-server-tunnel {local: 5588, remote: 5599}
    unless err
        console.log "tunnel is created "
