require! './actor-base': {ActorBase}
require! 'prelude-ls': {reject, find}
require! './topic-match': {topic-match}


export class ActorManager extends ActorBase
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this

        super \ActorManager
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
                    actor._inbox msg
                    break
