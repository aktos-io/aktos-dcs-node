require! '..': {Actor, sleep, TCPProxyClient}


class Ponger extends Actor
    ->
        super 'Ponger'
        @subscribe 'public.ponger'

        @on \data, (msg) ~>
            @log.log "got message: ", msg.payload
            <~ sleep 2000ms
            @send-response msg, 'this message is a response from ponger'


new TCPProxyClient {port: 5678} .login!
new Ponger!
