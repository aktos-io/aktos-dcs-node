require! '../../src/actor': {Actor}
require! './merge-deps': {merge-deps}

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
        super "CouchDcs #{opts.name or 'Client'}"
        if opts.topic
            @topic = that
        else if opts.prefix
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
        res = msg?.payload.res
        if opts.recurse
            merged-doc = merge-deps res.doc, that, res.recurse
            console.log "merged doc: ", merged-doc

        callback (err or msg?.payload.err), (merged-doc or res)

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
            timeout: opts.timeout or 5_000ms}, {put: doc}

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
        #@log.log "topic is: ", topic
        err, msg <~ @send-request {topic, timeout}, {follow: opts}
        if typeof! callback is \Function
            callback (err or msg?.payload.err), msg?.payload.res

    observe: (topic, callback) ->
        @on-topic topic, callback
        callback!
