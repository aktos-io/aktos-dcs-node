require! './actor': {Actor}
require! 'colors': {bg-red, red, bg-yellow}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}
require! './authentication': {AuthRequest, AuthHandler}


export class ProxyActor extends Actor
    ->
        """
        ProxyActor is a handler that any type of protocol (socket.io, tcp, etc...)
        uses as its handler.

        This handler forwards from `network` interface to `local`
        interface and vice versa.

        Before start forwarding, it opens a secure¹ and authenticated (optional)
        channel and modifies the outgoing and incoming messages.

        Client Mode Responsibilities:

            1. Add `token` to outgoing messages
            2. Subscribe to manager for authorized topics.
            3. forward any incoming network messages to manager
            4. Reconnect on disconnect if opts.reconnect is "yes"

        Authority Mode Responsibilities:

            1. forward/drop unauthorized incoming network messages
            2. forward/drop unauthorized outgoing network messages
            3. remove any `token` from incoming network messages
            4. subscribe to manager with authorized topics

        Parameters:
        ===========

            1. Socket, which has the following methods:
                1. write: send data by network interface
                2. on 'data', (data) -> : fired when data is received by network interface
                3. on 'error', (e) -> : fired on error
                4. on 'disconnect', -> : fired on disconnect

            2. Options:
                1. role (required): [ONE_OF 'client', 'authority']
                2. name (optional, default: this.id)
                3. creator (required): creator of this actor
                4. reconnect (optional, default: no): [yes/no]
                    This actor will try to reconnect or not

        ¹: TODO
        """
        super @opts.name, {+register-manually}



function unpack-telegrams data
    if typeof! data isnt \String
        return []

    boundary = data.index-of '}{'
    if boundary > -1
        [_first, _rest] = split-at (boundary + 1), data
    else
        _first = data
        _rest = null

    _first-telegram = try
        unpack _first
    catch
        console.log "data can not be unpacked: ", _first
        console.log e

    packets = flatten [_first-telegram, unpack-telegrams _rest]
    return packets


export class ProxyClient extends ProxyActor
    (@socket, @opts) ->
        super!
        # actor behaviours
        @role = \client

        /*
        # FIXME: Subscribe after authentication
        @subscribe '**'
        @mgr.register this
        */

        @auth = new AuthRequest!
        @auth.send-raw = (msg) ~>
            @socket.write pack msg

        @on do
            receive: (msg) ~>
                @log.log "forwarding message to network interface"
                if @socket-ready
                    auth.send-with-token msg
                else
                    @log.log bg-yellow "Socket not ready, not sending message..."

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"
                @socket.end!
                @socket.destroy 'KILLED'

            'network-receive': (msg) ->
                @log.log green "Network receive is triggered!"

            reconnect: ~>
                @socket-ready = no

        # network interface events
        @socket.on \disconnect, ~>
            @log.log "Client disconnected."
            #@kill \disconnect, 0

        @socket.on "data", (data) ~>
            # in "client mode", authorization checks are disabled
            # message is only forwarded to manager
            for msg in unpack-telegrams data.to-string!
                if \auth of msg
                    @log.log "received auth message, forwarding to AuthRequest."
                    @auth.inbox msg
                else
                    @log.log "received data: ", msg
                    @send-enveloped msg
                    @trigger \network-receive, msg

        @socket.on \error, (e) ~>
            if e.code in <[ EPIPE ECONNREFUSED ECONNRESET ETIMEDOUT ]>
                @log.err red "Socket Error: ", e.code
            else
                @log.err bg-red "Other Socket Error: ", e

            @trigger \reconnect, e.code

        @socket.on \end, ~>
            @log.log "socket end!"
            @trigger \reconnect

        @on \connected, ~>
            @log.log "Proxy knows that it is connected."
            @log.log "+---> New proxy connection established. name: #{@name}, role: #{@role}"
            @socket-ready = yes
            err, res <~ @auth.login {username: "user1", password: "hello world"}
            @log.log "there is error: ", err if err
            @log.log "authorization finished: ", res


export class ProxyAuthority extends ProxyActor
    (@socket, @opts) ->
        super!
        @role = \authority


        @auth = new AuthHandler @opts.db 
        @auth.send-raw = (msg) ~>
            @socket.write pack msg

        # actor behaviours
        @on do
            receive: (msg) ~>
                @log.log "received message from local interface:", pack msg

            kill: (reason, e) ~>
                @log.log "Killing actor. Reason: #{reason}"

            'network-receive': (msg) ->
                @log.log green "Network receive is triggered!"

        # network interface events
        @socket.on \disconnect, ~>
            @log.log "Client disconnected."
            #@kill \disconnect, 0

        @socket.on "data", (data) ~>
            # in "client mode", authorization checks are disabled
            # message is only forwarded to manager
            @log.log "received data", data.to-string!
            for msg in unpack-telegrams data.to-string!
                if \auth of msg
                    @auth.process msg
                else
                    @log.log "received data: ", msg

        @on \connected, ~>
            @log.log "Proxy knows that it is connected."
            @log.log "+---> New proxy connection established. name: #{@name}, role: #{@role}"
