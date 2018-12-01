require! '..': {Actor, sleep}

# Simulating very fast response

new class Foo extends Actor
    ->
        super!
        @on-topic 'foo', (msg) ~>
            @log.log "Got foo message: ", msg
            @send-response msg, {timeout: 1000ms, +ack, +part}, null
            @send-response msg, {-debug}, {+ok}


new class Bar extends Actor
    action: ->
        @log.log "sending request..."
        err, msg <~ @send-request 'foo', {+hello}
        @log.log "response is: ", err, msg


<~ :lo(op) ~>
    <~ sleep 10000000
    lo(op)
