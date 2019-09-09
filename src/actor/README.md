message =
    from: ID of sender actor's ID
    to: String or Array of routes that the message will be delivered to
    seq: Sequence number of message (integer, autoincremental). Every unique message
        receives a new sequence number. Partial messages share the same sequence number,
        they are identified with their `part` attribute.
    data: data of message

    # control attributes (used for routing)
    #------------------------------------------
    re: "#{from}.#{seq}" # optional, if this is a response for a request
    cc: "Carbon Copy": If set to true, message is also delivered to this route.
    res-token: One time response token for that specific response. Responses are dropped
        without that correct token.
    part: part number of this specific message, integer ("undefined" for single messages)
        Partial messages should include "part" attribute (0 based, autoincremented),
        `-1` for end of chunks.
        Streams should use `-2` as `part` attribute for every frame.
    req: true (this is a request, I'm waiting for the response)
    timeout: integer (wait at least for this amount of time for next part)

    # extra attributes
    #--------------------
    merge: If set to false, partials are concatenated by application (outside of)
        actor. If omitted, `aea.merge` method is used.
    permissions: Array of calculated user permissions.
    debug: if set to true, message highlights the route it passes

    # optional attributes
    #----------------------
    nack: true (we don't need acknowledgement message, just like UDP)
    ack: true (acknowledgement messages)
    timestamp: Unix time in milliseconds



ack message fields:
    from, to, seq, part?, re, +ack

Request message:
    Unicast:

        from, to: "@some-user.some-route", seq, part?, data?, +req

    Multicast:

        Not defined yet.

Response:
    Unicast response    : from, to, seq, re: "...",
    Multicast response  : from, to, seq, re: "...", +all,

        Response (0) -> part: 0, +ack

        Response (1..x) -> part: ++, data: ...

        Control messages:
            part: ++, heartbeat: 200..99999ms

        Response (end) -> part: -1, data: ...


Broadcast message:
    from, to: "**", seq, part?, data, +nack

    ("**": means "to all _available_ routes")


Multicast message:

    from, to: ["@some-user.some-route", ..], seq, part?, data?, +no_ack
