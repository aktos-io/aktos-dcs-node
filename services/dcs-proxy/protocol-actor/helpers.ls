require! '../../../lib': {sleep, pack, unpack, Logger, clone}
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

    rest-telegram = []
    rest-str = ''
    if _rest
        #console.log "there was a rest...................", _rest.length
        [rest-telegram, rest-str, a] = unpack-telegrams _rest
        if next-size > 0 and rest-telegram.length > 0
            next-size = 0


    #console.log "rest telegram: ", rest-telegram, "rest string is: ", rest-str

    packets = compact flatten [_first-telegram, rest-telegram]
    return [packets, rest-str, next-size]

export class MessageBinder
    ->
        @log = new Logger \MessageBinder
        @i = 0
        @cache = ""
        @heartbeat = 0
        const @timeout = 1400ms # needs a high value for extremely slow connections
        @max-try = 1200_chunks
        @next-size = 0

    append: (data) ->
        if typeof! data is \Uint8Array
            data = data.to-string!
        #@log.log "got message from network interface: ", data, (typeof! data)

        # len = data.to-string!.length
        # lens = if len < 200
        #     data.to-string!
        # else if len < 1000
        #     "#{len} Bytes"
        # else
        #     "#{len/1024}KB"
        # console.log "________data from transport: #{lens}"

        if @heartbeat < Date.now! - @timeout
            # there is a long time since last data arrived. do not cache anything
            #console.log "dropping current cache:", @cache
            @cache = ''
            @i = 0
            @next-size = 0

        @cache += data
        if @next-size > 0
            if @cache.length < @next-size
                #console.log "cache isnt enough, returning: cache.length: #{@cache.length}, ns: #{@next-size}"
                return []
            else
                @next-size = 0
        @i++

        if @i > @max-try
            @log.err "Caching isn't enough, giving up."
            @i = 0
            @cache = data
            @next-size = 0

        @heartbeat = Date.now!

        [res, y, size] = unpack-telegrams @cache
        # console.log "rest of cache is: ", y
        # console.log "unpacked: ", res
        # console.log "Next size is: #{size}"
        if size > 0
            @next-size = size
        @cache = y
        @i = 0

        return res
