export class EventEmitter
    ->
        @_events = {}
        @_one_time_events = {}

    once: (type, callback) ->
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


    on: (type, callback) ->
        """
        usage:

            with simple string name:

                .on 'name', fn

            or with an object:

                .on do
                    'name1': fn
                    'name2': fn2
        """
        add-listener = (type, callback) ~>
            if typeof! @_events[type] isnt \Array
                @_events[type] = []
            @_events[type].push callback.bind this

        switch typeof! type
            when \String =>
                add-listener type, callback
            when \Object =>
                for name, callback of type
                    add-listener name, callback

    off: (type) ->
        @_events[type] = []

    trigger: (type, ...args) ->
        """
        usage:

            .trigger "eventName", ...x

        """
        if @_events[type]
            for handler in that
                handler ...args

        if @_one_time_events[type]
            for i in [1 to that.length]
                handler = that.shift!
                handler ...args
