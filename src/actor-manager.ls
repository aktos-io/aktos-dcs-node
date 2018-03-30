require! 'prelude-ls': {reject, find}
require! './topic-match': {topic-match}
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

    distribute: (msg) ->
        for actor in @actors when actor.id isnt msg.sender
            #@log.log "looking for #{msg.topic} to be matched in #{actor.subscriptions}"
            for topic in actor.subscriptions
                if msg.topic `topic-match` topic
                    #@log.log "putting message: #{msg.sender}-#{msg.msg_id} -> actor: #{actor.id}"
                    actor._inbox msg
                    break
            else
                #@log.warn "dropping as topics are not matched: #{msg.topic} vs. #{topic}"
                null

    kill: (...args) ->
        for actor in @actors
            actor.trigger \kill, ...args
