require! '..': {Actor, sleep}

class Hello extends Actor
    ->
        super!

    action: ->
        <~ :lo(op) ~>
            @log.log "hello!"
            <~ sleep 1000ms
            lo(op)

class World extends Actor
    ->
        super!

    action: ->
        <~ :lo(op) ~>
            @log.log "world!"
            <~ sleep 2000ms
            lo(op)

new Hello!
new World!
