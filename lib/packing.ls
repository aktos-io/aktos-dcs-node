export function pack x
    JSON.stringify x, (key, val) ->
        if typeof! val is \Function
            return val + ''  # implicitly convert to string
        #else if val is undefined  => return null # DO NOT DO THAT!
        val

export function unpack x
    JSON.parse x

export class CloneError extends Error
    (@message, @argument) ->
        super ...
        Error.captureStackTrace(this, CloneError)


export clone = (x) ->
    if typeof! x in <[ Object Array ]>
        unpack pack x
    else
        throw new CloneError "argument must be object or array, supplied: #{pack x}", x


require! \jsondiffpatch

export diff = (a, b) ->
    jsondiffpatch.diff a, b 
