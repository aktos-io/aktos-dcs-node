require! './actor': {Actor}
require! 'aea': {pack, sleep}

export class RactiveActor extends Actor
    (@instance, opts) ->
        name = opts if typeof! opts is \String
        name = opts.name
        if @instance.get \wid
            super "#{name}-wid.#{that}", opts
            @subscribe "my.wid.#{that}"
        else
            super "#{name}", opts

        @instance.on \unrender, ~>
            @kill \unrender

        @on \data, (msg) ~>
            if \get of msg.payload
                keypath = msg.payload.get
                @log.log "received request for keypath: '#{keypath}'"
                val = @instance.get keypath
                @log.log "responding for #{keypath}:", val
                val = @instance.get keypath
                @log.log "responding for2222 #{keypath}:", val
                @log.warn "message for this request was: ", msg
                @send-response msg, {res: val}
