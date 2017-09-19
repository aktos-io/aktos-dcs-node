require! './actor': {Actor}
require! 'colors': {bg-red, red, bg-yellow, green, bg-blue}
require! 'aea': {sleep, pack, unpack, Logger}
require! 'prelude-ls': {split, flatten, split-at}


export function unpack-telegrams data
    if typeof! data isnt \String
        return []

    boundary = data.index-of '}{'
    if boundary > -1
        [_first, _rest] = split-at (boundary + 1), data
    else
        _first = data
        _rest = null

    _first-telegram = try
        unpack _first
    catch
        throw e

    packets = flatten [_first-telegram, unpack-telegrams _rest]
    return packets

export class MessageBinder
    ->
        @log = new Logger \MessageBinder
        @i = 0
        @cache = ""
        @heartbeat = 0
        const @timeout = 400ms
        @max-try = 120_chunks

    get-messages: (data) ->
        if typeof! data is \Uint8Array
            data = data.to-string!
        #@log.log "got message from network interface: ", data, (typeof! data)

        if @heartbeat < Date.now! - @timeout
            # there is a long time since last data arrived. do not cache anything
            @cache = data
            @i = 0
        else
            @cache += data
            @i++

        if @i > @max-try
            @log.err bg-red "Caching isn't enough, giving up."
            @i = 0
            @cache = data

        @heartbeat = Date.now!
        res = try
            x = unpack-telegrams @cache
            @cache = ""
            @i = 0
            x
        catch
            #@log.err bg-red "Problem while unpacking data, trying to cache.", e
            []
