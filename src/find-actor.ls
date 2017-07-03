require! './actor-manager': {ActorManager}
require! 'prelude-ls': {find}

export find-actor = (id) ->
    unless id
        console.error "id is required!"
        return void
    mgr = new ActorManager!
    return find (.id is id), mgr.actor-list
