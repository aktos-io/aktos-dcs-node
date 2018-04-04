export get-keypath = (obj, keypath) ->
    res = obj
    if keypath
        for k in keypath.split '.'
            res = try
                res[k]
            catch
                null
    return res

export set-keypath = (obj, keypath, value) ->
    _set = (_obj, _keypath) ->
        if _keypath.length is 0
            return _obj
        k = _keypath.shift!
        if _keypath.length is 0
            return _obj[k] = value
        else
            unless _obj[k] then _obj[k] = {}
            _set _obj[k], _keypath
        return _obj
    path = keypath?.split '.' or []
    return _set obj, path

"""
a =
    x: 1
    y: 2

x = set-keypath a, "a.b.c.d", 5
y = set-keypath a, "x", 4
debugger
"""

export delete-keypath = (obj, keypath) ->
    if keypath
        _keypath = keypath.split '.'
        first-prop = _keypath.shift!
        last-prop = _keypath.pop!
        tmp = obj[first-prop]
        for _keypath
            tmp = tmp[..]
        if last-prop of tmp
            delete tmp[last-prop]
        else
            throw "no such key"
    else
        for key of obj
            delete obj[key]
