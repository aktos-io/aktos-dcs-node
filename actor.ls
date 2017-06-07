require! './core': {ActorBase, envelp}
require! './actor-manager': {ActorManager}
require! 'prelude-ls': {
    split
}

export class Actor extends ActorBase
    (name) ->
        super ...
        @mgr = new ActorManager!
        @mgr.register this

        @actor-name = name
        @log.log "actor \"#{@name}\" created with id: #{@actor-id}"

        @msg-serial-number = 0
        @subscriptions = []

    subscribe: (topic) ->
        topics = [topic] if typeof! topic is \String
        for topic in topics when topic not in @subscriptions
            @subscriptions.push topic
        @mgr.subscribe-actor this

    list-handle-funcs: ->
        methods = [key for key of Object.getPrototypeOf this when typeof! this[key] is \Function ]
        subj = [s.split \handle_ .1 for s in methods when s.match /^handle_.+/]
        @log.log "this actor has the following subjects: ", subj, name

    send: (msg) ->
        try
            msg-env = envelp msg, @get-msg-id!
            @send_raw msg-env
        catch
            @log.err "sending message failed. msg: ", msg, "enveloped: ", msg-env, e

    send_raw: (msg_raw) ->
        msg_raw.sender = @actor-id
        @mgr.inbox-put msg_raw


    get-msg-id: ->
        msg-id = @actor-id + '.' + String @msg-serial-number
        @msg-serial-number += 1
        return msg-id
