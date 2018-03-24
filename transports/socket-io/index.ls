require! '../../lib': {EventEmitter}

export class SocketIOTransport extends EventEmitter
    (@orig) ->
        super!
        @orig.on \aea, (data) ~>
            @trigger \data, data

        @orig.on \disconnect, ~>
            @trigger \disconnect

        @orig.on \connect, ~>
            @trigger \connect

    write: (data) ->
        @orig.emit \aea, data
