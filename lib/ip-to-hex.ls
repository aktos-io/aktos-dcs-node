require! 'prelude-ls': {reverse}

export hex = (n) -> n.to-string 16 .to-upper-case!

export ip-to-hex = (ip) ->
    i = 0
    result = 0
    for part in reverse ip.split '.'
        result += part * (256**i++)

    hex result
