
/*
EXAMPLE FOR USE GO!
do
    console.log "waiting mahmut..."
    reason, param <- timeout-wait-for 10000ms, \mahmut
    console.log "mahmut happened! reason: ", reason, "param: ", param

do
    console.log "firing mahmut in 2 seconds..."
    <- sleep 2000ms
    go \mahmut, 5
    console.log "fired mahmut event!"

*/

require! '../src/signal': {Timeout}
require! 'aea/debug-log': {logger}
require! 'aea': {sleep}

log = new logger \signal-test

tests =
    * ->
        my-signal = new Timeout!
        log.log "signal will run because it will receive an event"
        do
            log.log "started coroutine 1"
            <- sleep 1000ms
            reason, arg1, arg2 <- my-signal.wait 10_000ms
            log.log "coroutine 1 continuing! reason: ", reason, "arg1: ", arg1, "arg2: ", arg2
            log.log "This should happen at +2000ms"

        do
            log.log "firing my-signal in 2 seconds..."
            <- sleep 2000ms
            my-signal.go \hello, \world
            log.log "fired my-signal! This should happen at +2000ms"

    * ->
        my-signal = new Timeout!
        log.log "signal will run because it will timeout"

        do
            log.log "started coroutine 1"
            <- sleep 500ms
            reason, arg1, arg2 <- my-signal.wait 500ms
            log.log "coroutine 1 continuing! reason: ", reason, "arg1: ", arg1, "arg2: ", arg2
            log.log "This should happen at +1000ms"

        do
            log.log "firing my-signal in 2 seconds..."
            <- sleep 2000ms
            my-signal.go \hello, \world
            log.log "fired my-signal! This should happen at +2000ms"


tests.1!
