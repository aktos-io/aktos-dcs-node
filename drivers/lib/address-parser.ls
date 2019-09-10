export parse-addr: (addr) ->
    # A static method for parsing addresses.
    # TODO: Move to a separate library.
    /* return type:

        {
            addr: Array
            value: WRITE value or amount of words to READ
        }
    */
    if typeof! addr is \Array
        # like ["C0100", 5]
        return do
            type: \bool
            addr: addr
    if typeof! addr is \String
        [addr, bit] = addr.split '.'
        if bit?
            # like "C0100.05", bool
            return do
                type: \bool
                addr: [addr, parse-int bit]
        else
            # like "C0100", word
            return do
                type: \word
                addr: addr
    else
        console.log "Typeof addr: ", (typeof! addr), addr