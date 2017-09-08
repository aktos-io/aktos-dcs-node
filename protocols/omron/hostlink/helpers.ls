require! 'prelude-ls': {
    chars, take, split-at, drop
}

export addr =
    relay: 'R'
    data: 'D'
    holding: 'H'

export calc-fcs = (packet) ->
    hex = (n) -> n.to-string 16 .to-upper-case!
    fcs = 0
    for c in chars packet
        fcs = fcs .^. c.charCodeAt(0)
    "00#{hex fcs}".slice -2

do test-calc-fcs = ->
    examples =
        * packet: "@00RD00000001", expected: "57"
        * packet: "@00RD00000002", expected: "54"
        * packet: "@00RD000008", expected: "5E"

    for index of examples
        example = examples[index]
        result = calc-fcs(example.packet)
        if result isnt example.expected
            throw "test-calc-fcs failed at: \##{index} (expected: #{example.expected}, result: #{result})"


export check-hostlink-packet = (packet) ->
    structure = // # check if input is a valid Hostlink query
        # returns true/false
        # --------------------------------------------
        | /^@          # start header
        | [0-3][0-9]   # unit no, must be 00-31
        | [RW]         # Command: [R]ead or [W]rite
        | [RDH]        # Memory type:
                       #   R: Common area
                       #   D: Data memory
                       #   H: Holding area
        | [0-9]{4}     # Address, 0000-9999 (BCD)
        | [0-9A-F]{4,} # Data or Size, 4 characters at least
        | [0-9A-F]{2}  # Frame Check Sequence
        | \*\r$/       # End header
        // .test packet

    if structure isnt true
        throw "Structure is not correct"

    packet = take (packet.length - 2), packet

    test-fcs = (packet) ->
        [packet, fcs] = split-at (packet.length - 2), packet
        throw 'FCS is not correct' if fcs isnt calc-fcs packet

    test-fcs packet

export get-data = (packet) ->
    packet = take (packet.length - 4), packet
    data-part = drop 7, packet
    slice-every = (n, str) ->
        result = []
        while str.length > 0
            [_first, str] = split-at n, str
            result.push _first
        result
    slice-every 4, data-part

export pad-two = (x) ->
    "00#{x}".slice -2
    
export pad-four = (x) ->
    "0000#{x}".slice -4
