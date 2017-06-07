require! 'aea': {sleep}
require! './core': {ActorBase, envelp}
require! './actor-manager': {ActorManager}
require! 'prelude-ls': {
    split
}

export class Actor extends ActorBase
    (name) ->
        super ...
        @mgr = new ActorManager!

        @actor-name = name
        @log.section \bare, "actor \"#{@name}\" created with id: #{@actor-id}"

        @msg-seq = 0
        @subscriptions = []

        # registering to ActorManager requires completion of this
        # constructor, so manually switch the context
        _this = @
        <- sleep 10ms
        _this.mgr.register _this

    subscribe: (topic) ->
        # log section prefix: s1
        topics = [topic] if typeof! topic is \String
        for topic in topics when topic not in @subscriptions
            @subscriptions.push topic
        @log.section \s1, "subscribing to ", topic, "subscriptions: ", @subscriptions
        @mgr.subscribe-actor this

    list-handle-funcs: ->
        methods = [key for key of Object.getPrototypeOf this when typeof! this[key] is \Function ]
        subj = [s.split \handle_ .1 for s in methods when s.match /^handle_.+/]
        @log.log "this actor has the following subjects: ", subj, name

    send: (msg) ~>
        try
            msg-env = envelp msg, @msg-seq++
            @send_raw msg-env
        catch
            @log.err "sending message failed. msg: ", msg, "enveloped: ", msg-env, e

    send_raw: (msg_raw) ->
        msg_raw.sender = @actor-id
        @mgr.inbox-put msg_raw
