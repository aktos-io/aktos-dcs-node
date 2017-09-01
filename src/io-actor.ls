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

    sync: (ractive-var, topic, rate=10fps) ->
        __ = @
        unless @ractive
            @log.err "set ractive variable first!"
            return

        unless topic
            @log.err 'Topic should be set first!'
            return

        @subscribe topic

        fps = new FpsExec rate
        first-time = yes
        handle = @ractive.observe ractive-var, (_new) ~>
            if first-time
                first-time := no
                return
            fps.exec @send, _new, topic


        @on \data, (msg) ~>
            unless msg.topic in @subscriptions
                @log.err "HOW COME WE GET SOMETHING WE DIDN'T SUBSCRIBE???"

            handle.silence!
            @ractive.set ractive-var, msg.payload
            handle.resume!
