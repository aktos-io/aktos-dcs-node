require! '../lib': {sleep}
require! 'dcs': {Actor, TCPProxyClient}
require! 'colors': {bg-green, bg-red}
require! './rpi-io': {DInput, DOutput}

class Simulator extends Actor
    ->
        super \simulator

        do
            i = 0
            <~ :lo(op) ~>
                @log.log "sending: #{i} to test-led"
                @send {val: i}, 'test-led'
                i := (++i) %% 2
                <~ sleep 1000ms
                lo(op)


console.log "starting..."
new DInput pin: 24, name: "hello"
new DOutput pin: 25, name: "test-led"
new Simulator!

#new TCPProxyClient port: 5588 .login {user: "simulator", password: "simulator"}
