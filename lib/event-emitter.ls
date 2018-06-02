require! 'prelude-ls': {reject}


export class EventEmitter
    ->
        @_events = {}
        @_one_time_events = {}

    once: (type, callback) !->
        add-listener = (type, callback) ~>
            if typeof! @_one_time_events[type] isnt \Array
                @_one_time_events[type] = []
            @_one_time_events[type].push callback.bind this

        switch typeof! type
            when \String =>
                add-listener type, callback
            when \Object =>
                for name, callback of type
                    add-listener name, callback


    on: (type, id, callback) !->
        """
        usage:

            with simple string name:

                .on 'name', fn

            or with an object:

                .on do
                    'name1': fn
                    'name2': fn2
        """
        if typeof! id is \Function
            callback = id
            id = null

        add-listener = (type, id, callback) ~>
            @_events[][type].push {id, cb: callback.bind this}

        switch typeof! type
            when \String =>
                add-listener type, id, callback
            when \Object =>
                for name, callback of type
                    add-listener name, id, callback

    off: (type) ->
        @_events[type] = []

    cancel: (id) !->
        # remove a handler with a specific id from @_events
        for type, listeners of @_events
            for i, listener of listeners
                if listener.id is id
                    listeners.splice i, 1
                    #console.log "removing #{id} from type: #{type}"
                    break

    trigger: (type, ...args) ->
        """
        usage:

            .trigger "eventName", ...x

        """
        if @_events[type]
            for let handler in that
                <~ set-immediate
                handler.cb ...args

        if @_one_time_events[type]
            for i in [1 to that.length]
                handler = that.shift!
                handler ...args

    has-listener: (ev) ->
        if @_events[ev]
            for that
                if typeof! ..cb is \Function
                    return true
        return false
