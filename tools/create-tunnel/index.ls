require! 'child_process': {exec}

# create ssh tunnel
ssh = "ssh -S /tmp/ssh-mobmac2@aktos.io:443.sock example -N"

export bind-server-to-local = (mapping, callback) ->
    if typeof! callback isnt \Function 
        callback = (err) -> 
            if err
                console.log "bind-server-to-local failed: ", err 
            else 
                console.log "bind-server-to-local success."
    {server-port, local-port} = mapping
    err, stdout, stderr <~ exec "#{ssh} -L #{local-port}:localhost:#{server-port}"
    callback err, {stdout, stderr}

export put-local-dcs-to-server = (mapping, callback) ->
    if typeof! callback isnt \Function 
        callback = (err) -> 
            if err
                console.log "put-local-dcs-to-server failed: ", err 
            else 
                console.log "bind-server-to-local success."
    {server-port, local-port} = mapping
    err, stdout, stderr <~ exec "#{ssh} -R #{server-port}:localhost:#{local-port}"
    callback err, {stdout, stderr}
