# for debugging purposes
require! colors: {
    green, gray, yellow, magenta
    bg-red, bg-yellow, cyan, bg-cyan, bg-green
}
require! moment
require! 'prelude-ls': {map}
require! './event-emitter': {EventEmitter}


NEED_STACK_TRACE = no

fmt = 'HH:mm:ss.SSS'

start-time = new moment

align-left = (width, inp) ->
    x = (inp + " " * width).slice 0, width

get-timestamp = ->
    # current time
    (new moment).format fmt

    # differential time
    #moment.utc(moment((new moment), fmt).diff(moment(startTime, fmt))).format(fmt)

get-prefix = (_source, color) ->
    color = gray unless color
    padded = align-left 15, "#{_source}"
    (color "[#{get-timestamp!}]") + " #{padded} :"

IS_NODE = do ->
    isNode = no
    if typeof process is \object
        if typeof process.versions is \object
            if typeof process.versions.node isnt \undefined
                isNode = yes
    return isNode

class LogManager extends EventEmitter
    @@instance = null
    ->
        return @@instance if @@instance
        super!
        @@instance := this
        @loggers = []

    register: (ctx) ->
        @loggers.push ctx


export class Logger extends EventEmitter
    (source-name, opts={}) ->
        super!
        @name = source-name
        @mgr = new LogManager!
        @prefix = null
        @error = @err 

    get-prefix: (color) ->
        get-prefix ("#{if @prefix => "#{@prefix}/" else ''}#{@name}"), color

    log: (...args) ~>
        prefix = get-prefix @name
        if IS_NODE
            console.log.call console, prefix, ...args
        else
            _args = []
            my = "%c"
            for arg in [prefix] ++ args
                _args.push arg
                my += " " + if typeof! arg is \String
                    "%s"
                else if typeof! arg is \Number
                    "%d"
                else
                    "%O"

            if NEED_STACK_TRACE
                console.group-collapsed my, "font-weight: normal;" ..._args
                console.trace prefix
                console.group-end!
            else
                log = Function.prototype.bind.call(console.log, console)
                log.call console, my, "font-weight: normal;" ..._args

    success: (...args) ~>
        console.error.apply console, ([@get-prefix bg-green] ++ args)

    err: (...args) ~>
        console.error.apply console, ([@get-prefix bg-red] ++ args)
        @trigger \err, ...args
        @mgr.trigger \err, ...args

    warn: (...args) ~>
        console.warn.apply console, [@get-prefix(bg-yellow), yellow('[WARNING]')] ++ args

    info: (...args) ~>
        console.info.apply console, [@get-prefix!, cyan('[I]')] ++ args

    todo: (...args) ~>
        console.warn.apply console, [@get-prefix!, magenta('[TODO]')] ++ args

    debug: (...args) ~>
        console.warn.apply console, [@get-prefix!, yellow('[D]')] ++ args
