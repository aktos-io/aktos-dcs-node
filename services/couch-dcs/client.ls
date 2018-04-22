require! '../../src/actor': {Actor}

'''
usage:

db = new CouchDcsClient prefix: 'myprefix'

err, res <~ db.get \my-doc
# sending message with topic: "myprefix.get"
unless err
    console.log "My document is: ", res

'''


export class CouchDcsClient extends Actor
    (opts) ->
        super if opts.name => "CouchDcs #{opts.name}" else "CouchDcsClient"
        if opts.topic
            @topic = that
        else if opts.prefix
            @topic = that
        else
            throw 'CouchDcsClient: No default topic is given.'
        @log.log "Initialized with topic: #{@topic}"

    get: (doc-id, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization
        timeout = opts.timeout or 5000ms
        err, msg <~ @send-request {topic: "#{@topic}.get", timeout}, {get: doc-id, opts: opts}
        res = msg?.payload.res
        err = err or msg?.payload.err
        if err
            err.message = "#{err.key}: #{err.error}"
        callback err, res

    all-docs: (opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization
        timeout = opts.timeout or 15000ms

        err, msg <~ @send-request {topic: "#{@topic}.allDocs", timeout}, {allDocs: opts}
        callback (err or msg?.payload.err), msg?.payload.res

    put: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request {
            topic: "#{@topic}.put"
            timeout: opts.timeout or 5_000ms}, {put: doc}

        callback (err or msg?.payload.err), msg?.payload.res

    put-transaction: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request {
            topic: "#{@topic}.put"
            timeout: opts.timeout or 5_000ms}, {put: doc, +transaction}

        callback (err or msg?.payload.err), msg?.payload.res

    view: (viewName, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization
        timeout = opts.timeout or 10_000ms
        err, msg <~ @send-request {topic: "#{@topic}.view", timeout}, {view: viewName, opts: opts}
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
        #@log.log "topic is: ", topic
        err, msg <~ @send-request {topic, timeout}, {follow: opts}
        if typeof! callback is \Function
            callback (err or msg?.payload.err), msg?.payload.res

    observe: (topic, callback) ->
        @on-topic topic, callback
        callback!
