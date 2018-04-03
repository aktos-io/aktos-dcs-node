require! 'dcs': {EventEmitter, Actor, sleep, Logger}
require! '../../src/errors': {CodingError}

require! 'prelude-ls': {find}

class SingularDriver
    (@driver) ->
        @busy = no
        @log = new Logger \sing.
        @queue = []
        @max-busy = 100ms

    run: (method, ...args, callback) !->
        if @busy
            #@log.info "busy! adding to queue."
            @queue.push [method, args, callback]
            return
        #@log.log "we are now going busy, args: ", ...args
        @busy = yes
        x = sleep @max-busy, ~>
            @log.warn "FORCE RUNNNING NEXT!"
            @next!
        @driver[method] ...args, (...ret) ~>
            if x
                clear-timeout x
                callback ...ret
                #@log.log "we are free"
                @next!
            else
                @log.err "what happened here?"

    next: ->
        @busy = no
        if @queue.length > 0
            #@log.info "Running from queue"
            next = @queue.shift!
            @run next.0, ...next.1, next.2

    read: (...args, callback) ->
        @run \read, ...args, callback

    write: (...args, callback) ->
        @run \write, ...args, callback

class LineUp
    @drivers = []
    (driver) ->
        if find (.driver is driver), @@drivers
            #console.log "Returning exitsting singular driver for: ", driver
            return that.singular
        else
            #console.log "Initialized new Lined up driver for: ", driver
            singular = new SingularDriver driver
            @@drivers.push {driver, singular}
            return singular


export class IoProxyHandler extends Actor
    (handle, driver) ->
        unless handle.constructor.name is \IoHandle
            throw new CodingError "handle should be an instance of IoHandle class"
        topic = handle.topic
        topic or throw new CodingError "A topic MUST be provided to IoProxyHandler."
        super topic
        #@log.info "Initializing #{handle.topic}"
        @subscribe "#{@name}.**"
        @subscribe "app.logged-in"

        /*
        @on \kill, (reason) ~>
            @log.log "KILLING ACTOR!!!"
        */

        prev = null
        curr = null
        RESPONSE_FORMAT = (err, curr) ->
            {err, res: {curr, prev}}

        broadcast-value = (err, value) ~>
            @send "#{@name}.read", RESPONSE_FORMAT(err, value)
            if not err and value isnt curr
                #@log.log "Store previous (broadcast) value (from #{prev} to #{curr})"
                prev := curr
                curr := value

        response-value = (msg) ~>
            (err, value) ~>
                @send-response msg, RESPONSE_FORMAT(err, value)
                if not err and value isnt curr
                    #@log.log "Store previous (resp.) value (from #{prev} to #{curr})"
                    prev := curr
                    curr := value

        if driver?
            safe-driver = new LineUp driver
            # assign handlers internally
            @on \read, (handle, respond) ~>
                #console.log "requested read!"
                err, value <~ safe-driver.read handle
                #console.log "responding read value: ", err, value
                respond err, value

            @on \write, (handle, value, respond) ~>
                #console.log "requested write for #{handle.address}, value: ", value
                err <~ safe-driver.write handle, value
                #console.log "write error status: ", err
                respond err

            # driver decides whether to watch changes of this handle or not.
            if handle.watch
                console.log "Watching #{handle.topic}"
                driver.watch-changes handle, broadcast-value


        @on-topic "#{@name}.read", (msg) ~>
            # send response directly to requester
            #@log.warn "triggering response 'read'."
            @trigger \read, handle, response-value(msg)

        @on-topic "#{@name}.write", (msg) ~>
            #@log.warn "triggering 'write'."
            new-value = msg.payload.val
            @trigger \write, handle, new-value, (err) ~>
                if err
                    # write failed, send response directly to the requester
                    @send-response msg, {err: err}
                else
                    # write succeeded, broadcast the value
                    broadcast-value err=null, new-value

        @on-topic "#{@name}.update", (msg) ~>
            # send response directly to requester
            #@log.warn "triggering 'read' because update requested."
            @trigger \read, handle, response-value(msg)

        @on-topic "app.logged-in", (msg) ~>
            # broadcast the status
            #@log.warn "triggering broadcast 'read' because we are logged in."
            @trigger \read, handle, broadcast-value

        # broadcast update on "power up"
        #@log.warn "triggering broadcast 'read' because we are initialized now."
        @trigger \read, handle, broadcast-value
