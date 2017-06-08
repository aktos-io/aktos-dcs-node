require! 'aea': {sleep}

export class FpsExec
    ->
        @period = 1000ms / 30fps
        @timer = null
        @last-sent = 0

    now: ->
        new Date! .get-time!

    exec: (func, ...args) ->
        try
            # do not send repetative messages in the time window
            if @now! > @last-sent + @period
                @last-sent = @now!
                # ready to send
            else
                clear-timeout @timer
        @timer = sleep @period, ->
            func.apply this, args


# ------------------- CLEANUP BELOW --------------------------- #
message-history = []    # msg_id, timestamp


aktos-dcs-filter = (msg) ->
    # filters out duplicate messages
    if server-id in msg.sender
        # drop short circuit message
        console.log "dropping short circuit message", msg.payload
        return null

    if 'ProxyActorMessage' of msg.payload
        # drop control message
        console.log "dropping control message", msg
        return null

    if msg.msg_id in [i.0 for i in message-history]
        # drop duplicate message
        console.log "dropping duplicate message: ", msg.msg_id
        return null


    message-history ++= [[msg.msg_id, msg.timestamp]]
    #console.log "message history: ", message-history

    return msg

cleanup-msg-history = ->
    now = Date.now! / 1000 or 0
    timeout = 10_s
    #console.log "msg history before: ", message-history.length
    message-history := [r for r in message-history when r.1 > now - timeout]
    #console.log "msg history after: ", message-history.length

set-interval cleanup-msg-history, 10000_ms
