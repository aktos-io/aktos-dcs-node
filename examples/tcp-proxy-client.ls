require! 'dcs': {Actor, TCPProxy}
require! 'aea': {sleep, pack}
require! 'colors': {bg-green, bg-red}

class Simulator extends Actor
    ->
        super \client-simulator
        @subscribe 'authorization.**'

        @on \receive, (msg) ~>
            @log.log "got message: ", msg.payload

    action: ->
        do ~>
            <~ :lo(op) ~>
                msg = "message from #{@name}...."
                @log.log "sending #{msg}"
                @send msg, 'authorization.test1'
                <~ sleep 2000ms
                lo(op)


proxy = new TCPProxy do
    server-mode: off
<~ sleep 100ms
proxy.login {username: "user1", password: "hello world"}, (err, res) ~>
    return console.log bg-red "Something went wrong while login: ", err if err
    return console.log bg-red "Wrong credentials?" unless res.auth?session?token

    console.log "Proxy logged in."

new Simulator!
