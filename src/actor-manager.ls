require! 'prelude-ls': {reject, find}
require! './topic-match': {topic-match: route-match}
require! '../lib': {Logger, sleep, hex}


export class ActorManager
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this
        #@log = new Logger \ActorManager
        @actor-uid = 1 # first actor id
        @actors = []
        @manager-id = Date.now! |> hex

    next-actor-id: ->
        "a#{@actor-uid++}-#{@manager-id}"

    register-actor: (actor) ->
        unless find (.id is actor.id), @actors
            @actors.push actor

    find-actor: (id) ->
        throw 'id is required!' unless id
        return find (.id is id), @actors

    deliver-to: (id, msg) ->
        @find-actor id ._inbox msg

    deregister-actor: (actor) ->
        @actors = reject (.id is actor.id), @actors

    distribute: (msg, sender) ->
        for actor in @actors when actor.id isnt sender
            #@log.log "looking for #{msg.to} to be matched in #{actor.subscriptions}"
            for route in actor.subscriptions
                if msg.to `route-match` route
                    #@log.log "putting message: #{msg.from}.#{msg.seq} -> actor: #{actor.id}"
                    actor._inbox msg
                    break
            else
                #@log.warn "dropping as routes are not matched: #{msg.to} vs. #{route}"
                null

    kill: (...args) ->
        for actor in @actors
            actor.trigger \kill, ...args
