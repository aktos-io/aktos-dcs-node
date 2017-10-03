require! '../../src/actor': {Actor}


export class CouchDcsClient extends Actor
    (opts) ->
        super "CouchDcs #{opts.name or 'Client'}"
        if opts.topic
            @topic = that
        else
            throw 'CouchDcsClient: No default topic is given.'

    get: (doc-id, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.get", {get: doc-id, opts: opts}
        callback (err or msg?.payload.err), msg?.payload.res

    all: (opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.all", {all: opts}
        callback (err or msg?.payload.err), msg?.payload.res

    put: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request {
            topic: "#{@topic}.put"
            timeout: opts.timeout or 20_000ms}, {put: doc}
        callback (err or msg?.payload.err), msg?.payload.res

    view: (viewName, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.view", {view: viewName, opts: opts}
        callback (err or msg?.payload.err), msg?.payload.res

    get-attachment: (doc-id, att-name, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        timeout = opts.timeout or 5000ms

        err, msg <~ @send-request {topic: "#{@topic}.getAtt", timeout}, do
            getAtt:
                doc-id: doc-id
                att-name: att-name
                opts: opts

        callback (err or msg?.payload.err), msg?.payload.res

    follow: (opts={}, callback) ->
        timeout = opts.timeout or 5000ms
        topic = "#{@topic}.follow"
        @log.log "topic is: ", topic
        err, msg <~ @send-request {topic, timeout}, {follow: opts}
        callback (err or msg?.payload.err), msg?.payload.res
