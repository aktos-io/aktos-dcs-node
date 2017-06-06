require! 'prelude-ls': {
        flatten,
        initial,
        drop,
        join,
        concat,
        tail,
        head,
        map,
        zip,
        split,
        union,
        last,
        empty,
        keys,
}
require! 'uuid4'
require! 'aea/debug-log': {logger, debug-levels}

export envelp = (msg, msg-id) ->
    msg-raw =
        sender: ''
        timestamp: Date.now! / 1000
        msg_id: msg-id    # {{.actor_id}}.{{serial}}
        payload: msg
        token: ''

export get-msg-body = (msg) ->
    subject = [subj for subj of msg.payload][0]
    #@log.log "subject, ", subject
    return msg.payload[subject]

class ActorBase
    (name) ->
        @actor-id = uuid4!
        @name = name
        @log = new logger (@name or @actor-id)
        #@log.log "ACTOR CREATED: ", @actor-id


    receive: (msg) ->
        @log.log "catch-all received", msg.text

    recv: (msg) ->
        try
            subjects = [subj for subj of msg.payload]
            for subject in subjects
                try
                    @log.debug-log "trying to call handle_#subject()"
                    this['handle_' + subject] msg
                catch
                    @receive msg
        catch
            @log.log "problem in handler: ", e


export class Actor extends ActorBase
    (name) ->
        super ...
        @mgr = new ActorManager!
        @mgr.register this, @subscriptions

        # register message types which are used in this
        # class with `handle_Subject` format
        #


        @actor-name = name
        @log.log "actor \"#{@name}\" created with id: #{@actor-id}"

        @msg-serial-number = 0

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

class _ActorManager extends ActorBase
    ->
        super \ActorManager
        @actor-list = []
        @subs-min-list = {}    # 'topic': [list of actors subscribed this topic]
        @log.level = debug-levels.silent

    register: (actor, subs) ->
        try
            for topic in subs
                try
                    @subs-min-list[topic] ++= [actor]
                catch
                    @subs-min-list[topic] = [actor]

            @log.log "\"#{actor.name}\" subscribed with following topics: ", subs
            #@log.log "actors subscribed so far: ", @subs-min-list
        catch
            @actor-list = @actor-list ++ [actor]
            @log.log "\"#{actor.name}\" subscribed to all topics"

        @log.log "Total actors subscribed: ", @actor-list.length

    inbox-put: (msg) ->
        @distribute-msg msg

    distribute-msg: (msg) ->
        # distribute subscribe-all messages
        i = 0
        @log.debug-log "------------ forwarding message ---------------"
        for actor in @actor-list when actor.actor-id isnt msg.sender
            @log.debug-log "------------ forwarding message to actor ---------------"
            @log.debug-log "forwarding msg: #{msg.msg_id} to #{actor.name}"
            @log.debug-log "actor: ", actor
            @log.debug-log "message: ", msg
            @log.debug-log "------------- end of forwarding to actor ---------------"

            actor.recv msg
            i++

        @log.debug-log "------------ end of forwarding message, total forward: #{i}---------------"

# make a singleton
class ActorManager
    instance = null
    ->
        instance ?:= new _ActorManager!
        return instance
