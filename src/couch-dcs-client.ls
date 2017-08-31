# -------------------------------------------------
require! './actor': {Actor}
require! './signal': {Signal}
require! 'aea': {pack}
require! 'aea/couch-helpers': {pack-id, unpack-id}

export class CouchDcsClient extends Actor
    (@doc-type) ->
        super \CouchProxy
        @get-signal = new Signal!
        @all-signal = new Signal!
        @put-signal = new Signal!
        @view-signal = new Signal!
        @get-att-signal = new Signal!

        @topic = "db.#{@doc-type}"
        @subscribe "#{@topic}.**"

        @on \data, (msg) ~>
            if \res of msg.payload
                err = msg.payload.err
                res = msg.payload.res

                # `get` message
                if msg.topic is "#{@topic}.get"
                    @get-signal.go err, res

                # `all` message
                else if msg.topic is "#{@topic}.all"
                    @all-signal.go err, res

                # `put` message
                else if msg.topic is "#{@topic}.put"
                    @put-signal.go err, res

                # `view` message
                else if msg.topic is "#{@topic}.view"
                    @view-signal.go err, res

                # `getAtt` message
                else if msg.topic is "#{@topic}.getAtt"
                    @get-att-signal.go err, res

                else
                    @log.err "unknown msg topic"

    pack-id: pack-id
    unpack-id: unpack-id

    get: (doc-id, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        @get-signal.clear!
        @send {get: doc-id, opts: opts}, "#{@topic}.get"
        reason, err, res <~ @get-signal.wait (opts.timeout or 5_000ms)
        err = {reason: \timeout} if reason is \timeout
        callback err, res

    all: (opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        @all-signal.clear!
        topic = "#{@topic}.all"
        #@log.log "sending `all` message. topic: #{topic}"
        @send {all: opts}, topic
        reason, err, res <~ @all-signal.wait (opts.timeout or 5_000ms)
        err = {reason: \timeout} if reason is \timeout
        callback err, res

    put: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        @put-signal.clear!
        @send {put: doc}, "#{@topic}.put"
        reason, err, res <~ @put-signal.wait (opts.timeout or 5_000ms)
        err = {reason: \timeout} if reason is \timeout
        callback err, res

    view: (_view, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        @view-signal.clear!
        @send {view: _view, opts: opts}, "#{@topic}.view"
        reason, err, res <~ @view-signal.wait (opts.timeout or 5_000ms)
        err = {reason: \timeout} if reason is \timeout
        callback err, res

    get-attachment: (doc-id, att-name, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        @get-att-signal.clear!
        @send {getAtt: {doc-id: doc-id, att-name: att-name, opts: opts}}, "#{@topic}.getAtt"
        reason, err, res <~ @get-att-signal.wait (opts.timeout or 10_000ms)
        err = {reason: \timeout} if reason is \timeout
        callback err, res
