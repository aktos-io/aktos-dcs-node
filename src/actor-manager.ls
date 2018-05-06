require! 'prelude-ls': {reject, find}
require! './topic-match': {topic-match: route-match}
require! '../lib': {Logger, sleep}


export class ActorManager
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this
        #@log = new Logger \ActorManager

        @actors = []

    register-actor: (actor) ->
        unless find (.id is actor.id), @actors
            @actors.push actor

    find-actor: (id) ->
        throw 'id is required!' unless id
        return find (.id is id), @actors

    deregister-actor: (actor) ->
        @actors = reject (.id is actor.id), @actors

    distribute: (msg, sender) ->
        for actor in @actors when actor.id isnt sender
            #@log.log "looking for #{msg.to} to be matched in #{actor.subscriptions}"
            for route in actor.subscriptions
                if msg.to `route-match` route
                    unless (msg.from.split '.' .0) is (msg.to.split '.' .0)
                        #@log.log "putting message: #{msg.from}.#{msg.seq} -> actor: #{actor.id}"
                        actor._inbox msg
                        break
                    else
                        console.log "dropping own message: ", msg, actor.id
            else
                #@log.warn "dropping as routes are not matched: #{msg.to} vs. #{route}"
                null

    kill: (...args) ->
        for actor in @actors
            actor.trigger \kill, ...args
