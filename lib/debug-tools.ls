export brief = (msg) ->
    s = {}
    for k, v of msg
        continue if k is \data
        s[k] = v
    if msg.data
        data-str = JSON.stringify msg.data
        s.data = if data-str.length > 70
            "...#{data-str.length}..."
        else
            msg.data
    if msg.permissions
        s.permissions = "...#{msg.permissions.length}..."
    return s
