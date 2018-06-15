require! 'prelude-ls': {reject, find}
require! './topic-match': {topic-match: route-match}
require! '../lib': {Logger, sleep, hex}
require! '../lib/debug-tools': {brief}


export class ActorManager
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this
        @actor-uid = 1 # first actor id
        @actors = []
        @manager-id = Date.now! |> hex
        @log = new Logger "ActorMan.#{@manager-id}"

    next-actor-id: ->
        "a#{@actor-uid++}-#{@manager-id}"

    register-actor: (actor) ->
        unless find (.id is actor.id), @actors
            @actors.push actor

    find-actor: (id) ->
        throw 'id is required!' unless id
        return find (.id is id), @actors

    deregister-actor: (actor) ->
        @actors = reject (.id is actor.id), @actors

    distribute: (msg, sender) ->
        if msg.debug => @log.debug "Distributing message: ", brief msg
        due-date = Date.now!
        for actor in @actors when actor.id isnt sender
            #@log.log "looking for #{msg.to} to be matched in #{actor.subscriptions}"
            if msg.to `route-match` actor.subscriptions
                #@log.log "putting message: #{msg.from}.#{msg.seq} -> actor: #{actor.id}", actor.subscriptions.join(',')
                delay = Date.now! - due-date
                if delay > 100ms
                    @log.warn "System load is high? Message is delivered after #{delay}ms"
                actor._inbox msg
            else
                #@log.warn "dropping as routes are not matched: #{msg.to} vs. #{route}"
                null

    kill: (...args) ->
        for actor in @actors
            actor.trigger \kill, ...args
