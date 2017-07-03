export class Wrapper
    (@orig) ->
        @handlers = {}
        @orig.on \aea, (data) ~>
            @trigger \data, data

        @orig.on \disconnect, ~>
            @trigger \end

    write: (data) ->
        @orig.emit \aea, data

    on: (_event, handler) ->
        @handlers[_event] = handler

    trigger: (_event, ...args) ->
        if @handlers[_event]
            that.apply that, args
