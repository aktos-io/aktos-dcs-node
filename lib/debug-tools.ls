export brief = (msg) ->
    s = {}
    for k, v of msg
        continue if k is \data
        s[k] = v
    if msg.data
        data-str = JSON.stringify msg.data
        if data-str.length > 70
            s.data = "...#{data-str.length}..."
    if msg.permissions
        s.permissions = "...#{msg.permissions.length}..."
    return s
