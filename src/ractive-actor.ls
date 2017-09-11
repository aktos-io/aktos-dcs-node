require! './actor': {Actor}
require! 'aea': {pack, sleep}
require! './signal': {Signal}

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
            @default-topic = "my.wid.#{that}"
            @subscribe @default-topic
            @log.log "Initializing RactiveActor. topic: #{@default-topic}"
        else
            super "#{name}", opts

        @subscribe 'my.router.changes'
        teleport-signal = new Signal

        @ractive.on do
            teardown: ~>
                @log.log "Ractive actor is being killed because component is tearing down"
                @kill \unrender

        orig-location = @ractive.target

        @on \data, (msg) ~>
            switch msg.topic

            when @default-topic =>
                if typeof! msg.payload is \Object
                    if \get of msg.payload
                        keypath = msg.payload.get
                        #@log.log "received request for keypath: '#{keypath}'"
                        #@log.log "responding for #{keypath}:", val
                        val = @ractive.get keypath
                        @send-response msg, {res: val}

                    else if \cmd of msg.payload
                        switch msg.payload.cmd
                        | \ctx      => @send-response msg, {res: @ractive.get-context! }
                        | \target   => @send-response msg, {res: @ractive.target}
                        | \ractive  => @send-response msg, {res: @ractive}
                        | \teleport =>
                            teleport-signal.clear!
                            @send-response msg, do
                                ractive: @ractive
                            timeout <~ teleport-signal.wait
                            @ractive.insert orig-location
                        | \teleport-restore => teleport-signal.go!
                        |_ => @log.err "Not a known command:", msg.payload.cmd

                else
                    debugger
            when 'my.router.changes'
                if msg.payload.scene
                    # put the node back only on scene changes
                    teleport-signal.go!
