/*

IoActor is an actor that subscribes IoMessage messages

# usage:

    # create instance
    actor = new IoActor 'pin-name'

    # send something
    actor.send-val 'some value to send'

    # receive something
    actor.handle_IoMessage = (msg) ->
        message handler that is fired on receive of IoMessage

 */

require! './core': {get-msg-body, Actor}
require! 'aea/debug-log': {logger}

export class IoActor extends Actor
    (pin-name) ->
        super name=pin-name

        unless pin-name
            @log.err "no pin_name supplied!"
            return
        @pin-name = pin-name

        @subscriptions =
            "IoMessage.pin_name.#{pin-name}"
            "ConnectionStatus"

        @log.log "actor is created with the following name: ", @actor-name, "and ID: #{@actor-id}"

    send-val: (val) ->
        @log.log "sending simple value: ", val
        @send IoMessage:
            pin_name: @pin-name
            val: val

    handle_IoMessage: (msg) ->
        ...

    handle_ConnectionStatus: (msg) ->
        @log.log "Not implemented, message: ", msg
