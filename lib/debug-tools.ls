export brief = (msg) ->
    s = {}
    for k, v of msg
        continue if k is \data
        s[k] = v
    s.data = "..."
    return s
