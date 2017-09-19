require! 'aea': {EventEmitter}

export class Wrapper extends EventEmitter
    (@orig) ->
        super!
        @handlers = {}
        @orig.on \aea, (data) ~>
            @trigger \data, data

        @orig.on \disconnect, ~>
            @trigger \end

        @orig.on \connect, ~>
            @trigger \connect

    write: (data) ->
        @orig.emit \aea, data
