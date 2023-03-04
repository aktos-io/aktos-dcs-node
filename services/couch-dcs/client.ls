require! '../../src/actor': {Actor}
require! '../../src/topic-match': {topic-match}
require! '../../src/errors':{CodingError}
require! '../../lib/sleep':{sleep}
require! 'prelude-ls': {first}
require! '../../lib/promisify': {upgrade-promisify}


export class CouchDcsClient extends Actor
    (opts) ->
        super if opts.name => "CouchDcs #{opts.name}" else "CouchDcsClient"
        if opts.route
            @route = that
        else
            throw new CodingError "Route is required."

        @on-every-login (msg) ~>
            if msg.data.routes `topic-match` opts.route
                @route = opts.route
                #@log.info "setting route as #{@route}"
                @trigger \logged-in
            else
                @log.warn "We won't be able to connect to #{opts.route},
                    not found in ", msg.data.routes

    __request: (data, callback) ->
        _err = null 
        _res = null
        retry = 0 
        limit = 3
        <~ :lo(op) ~> 
            err, res <~ @send-request {@route, debug: data.opts?.debug}, data
            _err := err 
            _res := res 
            if _err and retry++ < limit
                <~ sleep 100ms 
                lo(op)
            else
                return op!   
        if retry > 0 
            @log.warn "Retry is #{retry} and error is #{_err}"
        callback _err, _res 

    get: (doc-id, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = null
        opts = opts or {}

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        err, msg <~ @__request {get: doc-id, opts: opts}
        res = msg?.data?.res
        err = err or msg?.data.err
        if err
            err.message = "#{err.key}: #{err.error}"
        callback err, res


    all-docs: (opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = null
        opts = opts or {}

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        # end of normalization
        err, msg <~ @__request {allDocs: opts}
        callback (err or msg?.data.err), msg?.data?.res

    put: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = null
        opts = opts or {}
        # end of normalization

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        cmd = {put: doc}
        if opts.debug
            cmd <<< {opts: debug: true}
        err, msg <~ @__request cmd

        error = err or msg?.data.err
        response = msg?.data?.res
        unless error
            doc._id = response.id
            doc._rev = response.rev
        callback error, response

    delete: (doc, rev, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = null
        opts = opts or {}
        # end of normalization

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        cmd = {delete: [doc, rev]}
        if opts.debug
            cmd <<< {opts: debug: true}
        err, msg <~ @__request cmd

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
            opts = null
        opts = opts or {}
        # end of normalization

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        err, msg <~ @__request {put: doc, +transaction}
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

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        err, msg <~ @__request {view: viewName, opts: opts}
        callback (err or msg?.data.err), msg?.data?.res

    find: (query, callback) -> 
        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        err, msg <~ @__request {find: query}
        callback (err or msg?.data.err), msg?.data?.res

    get-attachment: (doc-id, att-name, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        err, msg <~ @__request do
            getAtt:
                doc-id: doc-id
                att-name: att-name
                opts: opts

        callback (err or msg?.data.err), msg?.data?.res

    follow: (opts={}, callback) ->
        #@log.log "route is: ", route
        err, msg <~ @__request {follow: opts}
        if typeof! callback is \Function
            callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

            callback (err or msg?.data.err), msg?.data?.res

    observe: (route, callback) ->
        @on-topic route, callback

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        callback!
