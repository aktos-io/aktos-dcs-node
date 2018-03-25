Description
============

ProxyClient/ProxyAuthority is an actor that uses any type of protocol (socket.io, tcp, etc...)
uses as its transport.

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

    1. subscribe to manager with authorized topics
    2. Deregister on end point disconnect

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

¹: TODO: Use TLS etc.
