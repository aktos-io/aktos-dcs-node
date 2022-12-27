require! '../../lib': {merge}
require! '../../lib/debug-tools': {brief}

export do
    send-request: (opts, data, callback) ->>
        """
        SETTINGS:
            
                Simple: "route-to-send"
                Full  : {to: "route-to-send", timeout, debug, ...}

        Single request: 

            Use one of the following styles:

            * control = @send-request SETTINGS, data, ((err, msg)->)
            * try 
                    msg = await @send-request "route-to-send", data
                catch
                    err = e 

            Where the `control` object has the following methods: 

                on-part: (func) ~>
                    part-handler := func
                on-receive: (func) ~>
                    complete-handler := func
                send-part: (data, last-part=yes) ~>

        Split request: (TO BE COMPLETED)
        
            First N parts   : `msg = await @send-request {to: "route-to-send", +part}, data`
            Last part       : `msg = await @send-request {to: "route-to-send", -part}, data` 

            This kind of requests will be concatenated on the receiver side. 


        """
        # normalize parameters
        meta = {}

        # FIXME:
        # this timeout should be maximum 1000ms but when another blocking data
        # receive operation is taking place, this timeout is exceeded
        timeout = 5_000ms # maximum timeout without target's first response
        # /FIXME

        if typeof! opts is \String
            meta.to = opts
        else
            meta.to = opts.topic or opts.route or opts.to
            timeout = that if opts.timeout

        seq = @msg-seq++
        request-id = "#{seq}"
        meta.part = @get-next-part-id opts.part, request-id

        meta.debug = yes if opts.debug

        if typeof! data is \Function
            # data might be null
            callback = data
            data = null

        promise = null 
        unless callback?
            # This method is used with `await`.
            promise = new Promise (_resolve, _reject) -> 
                callback := (err, res) -> 
                    if err then return _reject err 
                    _resolve res

        enveloped = meta <<< {from: @me, seq, data, +req, timestamp: Date.now!}

        # make preperation for the response
        @subscribe meta.to

        part-handler = ->
        complete-handler = ->
        last-part-sent = no
        reg-part-handlers =
            on-part: (func) ~>
                part-handler := func
            on-receive: (func) ~>
                complete-handler := func
            send-part: (data, last-part=yes) ~>
                if last-part-sent
                    @log.err "Last part is already sent."
                    return
                msg = enveloped <<< {data}
                msg.part = @get-next-part-id (not last-part), request-id
                #@log.todo "Sending next part: ", msg
                @log.log "Sending next part with id: ", msg.part
                @send-enveloped msg
                if last-part
                    last-part-sent := yes

        do
            response-signal = new Signal {debug: enveloped.debug, name: "ReqSig:#{enveloped.seq}"}
            #@log.debug "Adding request id #{request-id} to request queue: ", @request-queue
            @request-queue[request-id] = response-signal
            error = null
            prev-pieces = {}
            message = {}
            merge-method-manual = no
            request-date = Date.now! # for debugging (benchmarking) purposes
            <~ :lo(op) ~>
                #@log.debug "Request timeout is: #{timeout}"
                # -------------------------------------------------------
                # IMPORTANT: DO NOT remove this line to prevent "UNFINISHED" error
                response-signal.clear!
                # -------------------------------------------------------
                err, msg <~ response-signal.wait timeout
                if err
                    #@log.err "We have timed out"
                    error := err
                    return op!
                else
                    #@log.debug "GOT RESPONSE SIGNAL in ", msg.timestamp - enveloped.timestamp
                    part-handler msg

                    if request-date?
                        if msg.debug and (request-date + 200ms < Date.now!)
                            @log.debug "First response is too late for seq:#{enveloped.seq} latency:
                            #{Date.now! - request-date}ms, req: ", enveloped
                        request-date := undefined # disable checking

                    if msg.timeout
                        if enveloped.debug
                            @log.debug "New timeout is set from target: #{msg.timeout}
                                ms for request seq: #{enveloped.seq}"
                        timeout := msg.timeout
                    if msg.merge? and msg.merge is false
                        merge-method-manual := yes
                    unless merge-method-manual
                        message `merge` msg
                    if not msg.part? or msg.part < 0
                        /*
                        if not msg.part?
                            @log.debug "this was a single part response."
                        else
                            @log.debug "this was the last part of the message chain."
                        */
                        return op!
                lo(op)

            if @_state.kill-finished
                @log.warn "Got response activity after killed?", error, message
                return
            unless callback
                if error is \TIMEOUT
                    @log.warn "Request is timed out. Timeout was #{timeout}ms, seq: #{enveloped.seq}. req was:", brief enveloped
                    #debugger
            # Got the full messages (or error) at this point.
            @unsubscribe meta.to

            #@log.debug "Removing request id: #{request-id}"
            delete @request-queue[request-id]

            if merge-method-manual
                error := "Merge method is set to manual. We can't concat the messages."
            #@log.log "Received full message: ", message
            complete-handler error, message
            if typeof! callback is \Function
                callback error, message
        if meta.debug => @log.debug "Sending request seq: #{enveloped.seq}"
        @send-enveloped enveloped
        if promise
            return that 
        return reg-part-handlers

    send-response: (req, meta, data) ->
        """
        Normal response : @send-response received-message, data
        Partial response: @send-response received-message, {+part}, data 
        """
        unless req.req
            @log.err "No request is required, doing nothing."
            debugger
            return

        # normalize parameters
        if typeof! data is \Undefined
            data = meta
            meta = {}

        meta.part = @get-next-part-id meta.part, "#{req.from}.#{req.seq}"

        enveloped = {
            from: @me
            to: req.from
            seq: @msg-seq++
            data
            re: req.seq
            res-token: req.res-token
            debug: req.debug
        } <<< meta


        if req.debug or meta.debug
            @log.debug "sending the response for request: ", brief enveloped
        @send-enveloped enveloped