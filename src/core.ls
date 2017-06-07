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

export class ActorBase
    (name) ->
        @actor-id = uuid4!
        @name = name
        @log = new logger (@name or @actor-id)

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
