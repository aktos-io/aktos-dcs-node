# TODO: Merge with IoProxyClient

require! 'dcs': {Actor, sleep}

class IoManager
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this

        @targets = {}
        @io-proxies = {}

    register: (target, instance) -> 
        @io-proxies[][target].push instance 

    mark-last-heartbeat: (target, message) -> 
        @targets[target] = Date.now!
        if message
            console.log "Last heartbeat is updated by:", message

    get-last-heartbeat: (target) -> 
        @targets[target] or 0

    distribute-error: (target, reason) !-> 
        instances = @io-proxies[target] or []
        for instances
            ..set-error reason


export class IoProxy extends Actor
    (@opts) -> 
        /* 
        Options :: Object: 
            route: Route to communicate with.
            address: The io address that the driver expects.

        Methods:
            .write(value[, callback(err)]) : Writes the value. Returns Promise if callback is omitted.

        Events:
            .on-change callback(value)
            .on-state-change callback({error, busy, initialized})


        */
        throw new Error "target is required." unless @opts.route
        throw new Error "address is required." unless @opts.address

        @opts.name ?= @opts.route
        super("#{@opts.name}.#{@opts.address}")

        @manager = new IoManager
            ..register @opts.route, this 

        @is-initialized = no
        @is-busy = no 
        @value = null 
        @default_change_handler = (value, last_read) ~> 
            unless @is-initialized
                @is-initialized = yes 
                @_state_change_handler({+initialized})
            @set-busy(false)
            @value = value

        @_change_handler = @default_change_handler
        @_state_change_handler = -> 

        @refresh = 5_000ms
        @error = no
        @write-is-ongoing = false

        @_write_queue = []
        @_data_route = null 

    set-busy: (state) -> 
        state = Boolean state 
        if state? isnt @is-busy?
            @_state_change_handler({busy: state})
        @is-busy = state 

    on-change: (callback) ->
        @_change_handler = (value, last_read) ~> 
            @default_change_handler value, last_read
            callback value, last_read

    on-state-change: (callback) -> 
        @_state_change_handler = callback

    mark-last-heartbeat: ->
        #console.log "update heartbeat for: ", @_data_route
        @manager.mark-last-heartbeat(@opts.route, @_data_route)

    get-last-heartbeat: -> 
        @manager.get-last-heartbeat(@opts.route)

    set-error: (error) !-> 
        if @error? isnt error?
            @_state_change_handler {error}
        @error = error 

        unless error 
            @mark-last-heartbeat!
        @set-busy no 

    register: ->
        @set-busy yes 

        # Register for changes
        @send-request {route: "#{@opts.route}.watch", timeout: 1000ms}, [@opts.address], (err, msg) ~> 
            #console.log "watch response:", err, msg 
            unless err
                unless msg.data.err 
                    # run the handler with the initial read
                    @_change_handler msg.data.res.value
                @set-error(msg.data.err)

                @_data_route=(msg.data.res.route)
                if @_data_route not in @subscriptions
                    @on-topic @_data_route, (_msg) ~> 
                        unless _msg.data.err
                            @_change_handler _msg.data.value
                        @set-error _msg.data.err
            else
                @log.error "Can not refresh registering to: #{@opts.name}.#{@opts.address}"
                @set-error err 

            @set-busy no 

    start: ->>
        # Register for watching changes
        @_state_change_handler({-initialized})

        @on-every-login ~> 
            @register! 
        @on-topic "#{@opts.route}.restart", -> 
            console.log "Target is restarted"
            @set-error false
            @register!

        @on-topic "#{@opts.route}.stopped", (msg) ~> 
            @set-error true

        @on-topic "#{@opts.route}.started", (msg) ~> 
            @set-error false
            @register!


        # check if we have a connection with the driver server. 
        # note that we ignore the error if the end point has been disconnected
        heartbeat-timeout = 1000ms
        while true
            if @error or (Date.now! - @get-last-heartbeat!) > heartbeat-timeout
                console.log "Needed to check heartbeating by: #{@_data_route}"
                error = @error
                for to retry_on_error=3
                    try 
                        msg = await @send-request {route: "#{@opts.route}.heartbeat", timeout: 1000ms}, null
                        if msg.data.err 
                            throw new Error that 
                        error = null
                        @mark-last-heartbeat! # in order to prevent the other IoProxy instances to perform a parallel heartbeat checking
                        if @error?
                            @register!
                        break
                    catch 
                        error = e

                if error 
                    @manager.distribute-error(@opts.route, error)

            await sleep heartbeat-timeout


    write: (_value, _address) !->> 
        /* .write() method can be called frequently. If a previous write operation is ongoing, 
        only the last request will be queued for the next request. 

        Messages are sent to the "{route}.write" route.
        */
        if @write-is-ongoing  
            @_write_queue.length = 0 
            @_write_queue.push [_value, _address]
            return 
        else 
            @_write_queue.push [_value, _address]

        @set-busy yes 
        error = @error 
        while @_write_queue.length > 0
            [value, address] = @_write_queue.shift!
            try 
                @write-is-ongoing = true
                msg = await @send-request {route: "#{@opts.route}.write", timeout: (@opts.timeout or 1000ms)}
                    , [(address or @opts.address), +value]
                if msg.data.err
                    throw new Error that 
                @value = value 
                error = null 
            catch 
                # There is an error, set the error flag 
                error = e 
        @write-is-ongoing = false # must be before the handlers in order to use inside the handlers
        @set-error error
        @_change_handler @value

    read: (address, length=1) -> 
        address ?= @opts.address 

        return new Promise (_resolve, _reject) ~>> 
            try 
                msg = await @send-request "#{@opts.route}.read", [address, length]
                if msg.data.err
                    throw new Error that
                _resolve(msg.data.res)
            catch
                _reject(e)

if false
    do ->>
        require! 'dcs': {DcsTcpClient}
        new DcsTcpClient port: 4012 .login {user: "monitor", password: "test"}
        x = new OmronIo {route: "my1", address:"d21", fps: 1}
        x.on-change (value, timestamp) -> 
            console.log "#{@opts.address} changed:", value

        await sleep 2000ms
        
        for i to 300
            try x.write i      # <-------------- TODO: This causes: UnhandledPromiseRejection: This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). The promise rejected with the reason "TIMEOUT".
        

        /*
        await sleep 2000ms
        try
            res = await x.read "d28.1"
            console.log "d28 is:", res 
        catch 
            console.log "couldn't read d28"
        */
