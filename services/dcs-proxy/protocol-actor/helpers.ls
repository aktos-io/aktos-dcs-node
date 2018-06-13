require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! '../deps': {pack, unpack, Logger}
require! 'prelude-ls': {split, flatten, split-at, compact}

'''
Method: Concatenated JSON + Lenght Prefixed JSON (https://en.wikipedia.org/wiki/JSON_streaming)

Concatenated JSON is valid:

    {"from":"...",to:"...",...}{"from":"...",to:"...",...}

Magic packet prefixes is also valid:

    {size:12345}{"from":"...",to:"...",...}

...where the "{size: xxx}" packet tells the following JSON length, which dramatically
saves the time and CPU power for large messages.

'''


function unpack-telegrams data
    """
    Search for valid JSON telegrams recursively
    """
    boundary = data.index-of '}{'
    [_first, _rest] = compact split-at (boundary + 1), data
    #console.log "first len: #{_first.length}, rest length: #{_rest?length}"

    next-size = 0
    try
        _first-telegram = unpack _first
    catch
        #console.log "we don't have the whole telegram? ", data
        return [[], data, next-size]

    if _first-telegram?size
        next-size = that
        # this is a magic packet, not a real packet, remove it
        _first-telegram = null

    [rest-telegram, rest-str, a] = if _rest
        #console.log "there was a rest...................", _rest.length
        unpack-telegrams _rest
    else
        [[], '', 0]

    #console.log "rest telegram: ", rest-telegram, "rest string is: ", rest-str

    packets = compact flatten [_first-telegram, rest-telegram]
    return [packets, rest-str, next-size]

export class MessageBinder
    ->
        @log = new Logger \MessageBinder
        @i = 0
        @cache = ""
        @heartbeat = 0
        const @timeout = 400ms
        @max-try = 1200_chunks
        @next-size = 0

    append: (data) ->
        if typeof! data is \Uint8Array
            data = data.to-string!
        #@log.log "got message from network interface: ", data, (typeof! data)

        if @heartbeat < Date.now! - @timeout
            # there is a long time since last data arrived. do not cache anything
            @cache = ''
            @i = 0
            @next-size = 0

        @cache += data
        if @next-size > 0
            if @cache.length < @next-size
                return []
            else
                @next-size = 0
        @i++

        if @i > @max-try
            @log.err bg-red "Caching isn't enough, giving up."
            @i = 0
            @cache = data
            @next-size = 0

        @heartbeat = Date.now!

        [res, y, size] = unpack-telegrams @cache
        #console.log "rest of cache is: ", y
        #console.log "unpacked: ", x
        #console.log "Next size is: #{size}"
        if size > 0
            @next-size = size
        @cache = y
        @i = 0

        return res
