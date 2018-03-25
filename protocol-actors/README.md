# Protocol Actors

A protocol actor is a "connector without a *transport*"

## Implementation

Extend a protocol actor and supply a transport to its constructor:

### Client


```ls
export class TcpDcsClient extends ProxyClient
    (@opts={}) ->
        super!
        transport = new TcpTransport do
            host: @opts.host or \127.0.0.1
            port: @opts.port or 5523

        super transport, do
            name: \TcpDcsClient
            creator: this
            forget-password: no
```

Here, transport is expected to be a valid [transport](../transports).

### Server
