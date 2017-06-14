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

require! './actor': {Actor}
require! './filters': {FpsExec}

export class IoActor extends Actor
    (pin-name) ->
        super name=pin-name

        unless pin-name
            @log.err "no pin_name supplied!"
            return
        @pin-name = pin-name
        @subscriptions =
            "IoMessage.#{pin-name}"
            "ConnectionStatus"

        @log.section \vvv, "actor is created with the following name: ", @actor-name, "and ID: #{@actor-id}"

    handle_ConnectionStatus: (msg) ->
        @log.log "Not implemented, message: ", msg

    sync: (ractive-var, topic=null, rate=20fps) ->
        __ = @
        unless @ractive
            @log.err "set ractive variable first!"
            return

        unless topic
            topic = "IoMessage.#{@pin-name}"

        @subscribe topic

        fps = new FpsExec rate
        handle = @ractive.observe ractive-var, (_new) ~>
            fps.exec @send, _new, topic

        @on-receive (msg) ~>
            if msg.topic in @subscriptions
                # payload has this topic
                handle.silence!
                @ractive.set ractive-var, msg.payload
                handle.resume!
