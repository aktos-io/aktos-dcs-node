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
require! 'aea': {sleep}

context-switch = sleep 0

export class IoActor extends Actor
    (@pin-name) ->
        super @pin-name

    post-init: ->
        @subscribe "ConnectionStatus"
        @subscribe "io.#{@pin-name}" if @pin-name
        #@log.log "this is post init, subscriptions:", @subscriptions


    action :->
        @log.section \vvv, "actor is created with the following name: ", @actor-name, "and ID: #{@actor-id}"

    handle_ConnectionStatus: (msg) ->
        @log.log "Not implemented, message: ", msg

    sync: (ractive-var, topic=null, rate=20fps) ->
        __ = @
        unless @ractive
            @log.err "set ractive variable first!"
            return

        unless topic
            @log.err 'Topic should be set first!'
            return

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

    request-update: ->
        <~ context-switch
        @log.log "requesting update!"
        for topic in @subscriptions
            @log.log "...requesting update for #{topic}"
            msg = @get-msg-template!
            msg.update = yes
            msg.topic = topic
            @send-enveloped msg
