# -------------------------------------------------
require! './actor': {Actor}
require! './signal': {Signal}
require! 'aea': {pack}
require! 'aea/couch-helpers': {pack-id, unpack-id}

export class CouchDcsClient extends Actor
    (@doc-type) ->
        super \CouchProxy
        @topic = "db.#{@doc-type}"
        @subscribe "#{@topic}.**"

    pack-id: pack-id
    unpack-id: unpack-id

    get: (doc-id, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.get", {get: doc-id, opts: opts}
        callback (err or msg.payload.err), msg.payload.res

    all: (opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.all", {all: opts}
        callback (err or msg.payload.err), msg.payload.res

    put: (doc, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.put", {put: doc}
        callback (err or msg.payload.err), msg.payload.res

    view: (viewName, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.view", {view: viewName, opts: opts}
        callback (err or msg.payload.err), msg.payload.res

    get-attachment: (doc-id, att-name, opts, callback) ->
        # normalize parameters
        if typeof! opts is \Function
            callback = opts
            opts = {}
        # end of normalization

        err, msg <~ @send-request "#{@topic}.getAtt", {
            getAtt:
                doc-id: doc-id
                att-name: att-name
                opts: opts
            }, {timeout: 3000ms}

        callback (err or msg.payload.err), msg.payload.res
