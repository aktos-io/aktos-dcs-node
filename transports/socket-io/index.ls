require! '../../lib': {EventEmitter}

export class SocketIOTransport extends EventEmitter
    (@orig) ->
        super!
        # data received
        @orig.on \aea, (data) ~>
            #console.log ">>> socket-io data received: ", data
            @trigger \data, data

        # disconnected
        @orig.on \disconnect, ~>
            @trigger \disconnect

        # connected
        @orig.on \connect, ~>
            @trigger \connect

    write: (data) ->
        #console.log "<<< socket-io data write: ", data
        @orig.emit \aea, data
