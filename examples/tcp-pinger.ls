require! '..': {Actor, sleep, TCPProxyServer}


class Pinger extends Actor
    ->
        super 'Pinger'

    action: ->
        <~ :lo(op) ~>
            <~ sleep 1000ms
            @log.log "sending request from pinger"
            <~ @send-request 'public.ponger', 'this is a request from ponger'
            @log.log "received response from ponger"
            lo(op)


# If authentication and authorization is required, pass a `AuthDB` object
# to TCPProxyServer:
#
#     require! './users-and-permissions': {users, permissions}
#     db = new AuthDB users, permissions
#
new TCPProxyServer do
    port: 5678

new Pinger!
