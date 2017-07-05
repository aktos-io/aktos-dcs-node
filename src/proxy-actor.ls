require! './actor': {Actor}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack}
require! 'prelude-ls': {split, flatten, split-at}


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

            1. [x] Add `token` to outgoing messages
            2. [x] Subscribe to manager for authorized topics.
            3. forward any incoming network messages to manager
            4. Reconnect on disconnect if opts.reconnect is "yes"

        Authority Mode Responsibilities:

            1. [ ] remove any `token` from incoming network messages
            2. [x] subscribe to manager with authorized topics
            3. [x] Deregister on end point disconnect

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
        super @opts.name



export function unpack-telegrams data
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
        throw e

    packets = flatten [_first-telegram, unpack-telegrams _rest]
    return packets
