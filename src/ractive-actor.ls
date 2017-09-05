require! './actor': {Actor}
require! 'aea': {pack}

export class RactiveActor extends Actor
    (@instance, name) ->
        if @instance.get \wid
            super "#{name}-wid.#{that}"
            @subscribe "my.wid.#{that}"
        else
            super "#{name}"

        @on \data, (msg) ~>
            if \get of msg.payload
                keypath = msg.payload.get
                val = @instance.get keypath
                @log.log "requested getting #{keypath}, which is :", val
                @send-response msg, {res: @instance.get keypath}

    request: (topic, msg, callback) ->
        cancel = @subscribe-tmp topic
        err, msg <~ @send-request topic, msg
        cancel!
        callback err, msg
