require! './actor': {Actor}
require! 'aea': {pack}

export class RactiveActor extends Actor
    (@instance) ->
        super!

        if @instance.get \wid
            @subscribe "my.wid.#{that}"

        @on \data, (msg) ~>
            if \get of msg.payload
                keypath = msg.payload.get
                @log.log "requested getting #{keypath}, which is : #{pack @instance.get keypath}"
                @send-response msg, {res: @instance.get keypath}

    request: (topic, msg, callback) ->
        cancel = @subscribe-tmp topic
        err, msg <~ @send-request topic, msg
        cancel!
        callback err, msg
