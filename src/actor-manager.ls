require! 'prelude-ls': {reject, find}
require! './topic-match': {topic-match}


export class ActorManager
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this

        @actors = []

    register-actor: (actor) ->
        unless find (.id is actor.id), @actors
            @actors.push actor

    deregister-actor: (actor) ->
        @actors = reject (.id is actor.id), @actors

    distribute: (msg) ->
        for actor in @actors when actor.id isnt msg.sender
            for topic in actor.subscriptions
                if msg.topic `topic-match` topic
                    #@log.log "putting message: #{msg.sender}-#{msg.msg_id} -> actor: #{actor.id}"
                    actor._inbox msg
                    break

    kill: (...args) ->
        for actor in @actors
            actor.trigger \kill, ...args
