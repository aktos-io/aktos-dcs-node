require! '../../src/actor': {Actor}
require! '../../src/topic-match': {topic-match}
require! '../../src/errors':{CodingError}
require! 'prelude-ls': {first}

'''
usage:

db = new CouchDcsClient route: "@db-proxy"

err, res <~ db.get \my-doc
# sending message with topic: "myprefix.get"
unless err
    console.log "My document is: ", res

'''

export class CouchDcsClient extends Actor
    (opts) ->
        super if opts.name => "CouchDcs #{opts.name}" else "CouchDcsClient"
        unless opts.route => throw new CodingError "Route is required."

        @on-every-login (msg) ~>
            if msg.data.routes `topic-match` opts.route
                @route = opts.route
                @log.info "setting route as #{@route}"
            else
                @log.err "We won't be able to connect to #{opts.route},
                    not found in ", msg.data.routes

    __request: (opts={}, data, callback) ->
        unless @route
            debugger
            @log.err "No route is defined (yet?). Dropping request:", data
        else
            timeout = opts.timeout or 5000ms
            #@log.debug "request timeout: ", timeout 
            @send-request {@route, timeout}, data, callback

    get: (doc-id, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization
        timeout = opts.timeout or 5000ms
        err, msg <~ @__request {timeout}, {get: doc-id, opts: opts}
        res = msg?.data?.res
        err = err or msg?.data.err
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
        err, msg <~ @__request {@route, timeout}, {allDocs: opts}
        callback (err or msg?.data.err), msg?.data?.res

    put: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        timeout = opts.timeout or 5_000ms
        err, msg <~ @__request {@route, timeout}, {put: doc}

        error = err or msg?.data.err
        response = msg?.data?.res
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
        err, msg <~ @__request {@route, timeout}, {put: doc, +transaction}

        error = err or msg?.data.err
        response = msg?.data?.res
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
        err, msg <~ @__request {@route, timeout}, {view: viewName, opts: opts}
        callback (err or msg?.data.err), msg?.data?.res

    get-attachment: (doc-id, att-name, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        timeout = opts.timeout or 5000ms

        err, msg <~ @__request {@route, timeout}, do
            getAtt:
                doc-id: doc-id
                att-name: att-name
                opts: opts

        callback (err or msg?.data.err), msg?.data?.res

    follow: (opts={}, callback) ->
        timeout = opts.timeout or 5000ms
        #@log.log "route is: ", route
        err, msg <~ @__request {@route, timeout}, {follow: opts}
        if typeof! callback is \Function
            callback (err or msg?.data.err), msg?.data?.res

    observe: (route, callback) ->
        @on-topic route, callback
        callback!
