require! '../../lib': {EventEmitter}

export class TcpHandlerTransport extends EventEmitter
    (@orig) ->
        super!
        @orig
            ..on \end, ~>
                @trigger \disconnect

            ..on \data, ~>
                @trigger \data, ...arguments

    write: (data) ->
        @orig.write data
