require! './actor': {Actor}
require! 'aea': {pack, sleep}

export class RactiveActor extends Actor
    (@ractive, opts) ->
        name = if typeof! opts is \String
            opts
        else if opts?.name
            that
        else
            'RactiveActor'

        if @ractive.get \wid
            super "#{name}-wid.#{that}", opts
            @subscribe "my.wid.#{that}"
        else
            super "#{name}", opts

        @ractive.on do
            teardown: ~>
                @log.log "Ractive actor is being killed because component is tearing down"
                @kill \unrender

        @on \data, (msg) ~>
            if typeof! msg.payload is \Object
                if \get of msg.payload
                    keypath = msg.payload.get
                    #@log.log "received request for keypath: '#{keypath}'"
                    #@log.log "responding for #{keypath}:", val
                    val = @ractive.get keypath
                    @send-response msg, {res: val}
