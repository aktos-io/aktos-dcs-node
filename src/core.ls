require! 'uuid4'
require! 'aea/debug-log': {logger, debug-levels}
require! 'aea': {sleep}

export envelp = (msg, msg-id) ->
    console.log "WARNING: envelp function is deprecated. use @get-msg-template! instead."
    msg-raw =
        sender: ''
        timestamp: Date.now! / 1000
        msg_id: msg-id    # {{.actor_id}}.{{serial}}
        payload: msg
        topic: '*'
        token: ''

export get-msg-body = (msg) ->
    console.log "THIS FUNCTION WILL BE REMOVED"
    return
    subject = [subj for subj of msg.payload][0]
    #@log.log "subject, ", subject
    return msg.payload[subject]

export class ActorBase
    (name) ->
        @actor-id = uuid4!
        @name = name
        @log = new logger (@name or @actor-id)

        @receive-handlers = []
        @msg-seq = 0
        <~ sleep 0
        @post-init!

    post-init: ->

    on-receive: (handler) ->
        @log.section \debug1, "adding handler to run on-receive..."
        if typeof! handler isnt \Function
            @log.err "parameter passed to 'on-receive' should be a function."
            return
        @receive-handlers.push handler

    get-msg-template: ->
        msg-raw =
            sender: @actor-id
            timestamp: Date.now! / 1000
            msg_id: @msg-seq++
            topic: void
            token: void


    receive: ->
        ...

    recv: (msg) ->
        try
            # distribute according to subscriptions
            for handler in @receive-handlers
                @log.section \recv-debug, "firing receive handler..."
                handler.call this, msg
        catch
            @log.err "problem in handler: ", e
