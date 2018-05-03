require! '../../src/actor': {Actor}
require! '../../src/topic-match': {topic-match}
require! '../../src/errors':{CodingError}
require! 'prelude-ls': {first}

'''
usage:

db = new CouchDcsClient topic: 'db'

err, res <~ db.get \my-doc
# sending message with topic: "myprefix.get"
unless err
    console.log "My document is: ", res

'''

export class CouchDcsClient extends Actor
    (opts) ->
        super if opts.name => "CouchDcs #{opts.name}" else "CouchDcsClient"
        unless opts.topic => throw new CodingError "Topic is required."
        #@topic = opts.topic
        @on-every-login (msg) ~>
            for msg.payload.permissions.rw
                if .. `topic-match` "#{opts.topic}.**"
                    @log.info "setting topic as #{..}"
                    @topic = ..

    get: (doc-id, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization
        timeout = opts.timeout or 5000ms
        err, msg <~ @send-request {@topic, timeout}, {get: doc-id, opts: opts}
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
        err, msg <~ @send-request {@topic, timeout}, {allDocs: opts}
        callback (err or msg?.payload.err), msg?.payload.res

    put: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        timeout = opts.timeout or 5_000ms
        err, msg <~ @send-request {@topic, timeout}, {put: doc}

        error = err or msg?.payload.err
        response = msg?.payload.res
        unless error
            doc._id = response.id
            doc._rev = response.rev
        callback error, response

    put-transaction: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization
        timeout = opts.timeout or 5_000ms
        err, msg <~ @send-request {@topic, timeout}, {put: doc, +transaction}

        error = err or msg?.payload.err
        response = msg?.payload.res
        unless error
            doc._id = response.id
            doc._rev = response.rev
        callback error, response

    view: (viewName, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization
        timeout = opts.timeout or 10_000ms
        err, msg <~ @send-request {@topic, timeout}, {view: viewName, opts: opts}
        callback (err or msg?.payload.err), msg?.payload.res

    get-attachment: (doc-id, att-name, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        timeout = opts.timeout or 5000ms

        err, msg <~ @send-request {@topic, timeout}, do
            getAtt:
                doc-id: doc-id
                att-name: att-name
                opts: opts

        callback (err or msg?.payload.err), msg?.payload.res

    follow: (opts={}, callback) ->
        timeout = opts.timeout or 5000ms
        #@log.log "topic is: ", topic
        err, msg <~ @send-request {@topic, timeout}, {follow: opts}
        if typeof! callback is \Function
            callback (err or msg?.payload.err), msg?.payload.res

    observe: (topic, callback) ->
        @on-topic topic, callback
        callback!
