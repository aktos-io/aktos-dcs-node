export brief = (msg) ->
    s = {}
    for k, v of msg
        continue if k is \data
        s[k] = v
    if msg.data
        s.data = "...#{JSON.stringify msg.data .length}..."
    return s
