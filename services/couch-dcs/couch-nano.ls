require! 'prelude-ls': {flatten, join, split}
require! 'nano'
require! 'colors': {bg-red, bg-green, bg-yellow, bg-blue}
require! '../../lib': {Logger, sleep, pack, EventEmitter, merge, clone}
require! 'cloudant-follow': follow
require! '../../src/signal': {Signal}

UNAUTHORIZED = 401
FORBIDDEN = 403

export class CouchNano extends EventEmitter
    """
    Events:

        * connected
        * disconnected
        * refresh-cookie
        * error

    """
    (@cfg) ->
        super!
        @log = new Logger "db:#{@cfg.database}"
        @username = @cfg.user.name
        @password = @cfg.user.password
        @db-name = @cfg.database
        @db = nano {url: @cfg.url, parseUrl: no}
        @connection = new Signal!
        @first-connection-made = no

        @on \connected, ~>
            @connection.go!
            @connected = yes
            @retry-timeout = 100ms
            @first-connection-made = yes
            #console.log "couch-nano says: connected"

        @on \disconnected, ~>
            @connected = no
            #console.log "couch-nano says: disconnected!"

        @retry-timeout = 100ms
        @max-delay = 12_000ms

        @security-is-okay = no

    request: (opts, callback) ~>
        opts.headers = {} unless opts.headers
        opts.headers['X-CouchDB-WWW-Authenticate'] = 'Cookie'
        opts.headers.cookie = @cookie

        unless typeof! callback is \Function => callback = (->)

        #console.log "request opts : ", opts
        err, res, headers <~ @db.request opts
        if (err?.statusCode in [UNAUTHORIZED, FORBIDDEN]) or err?code is 'ECONNREFUSED'
            if @first-connection-made
                @trigger \disconnected, {err}
            @log.log "Retrying connection because:", (err.reason or err.description)
            sleep @retry-timeout, ~>
                @log.log "Retrying connection..."
                @_connect (err) ~>
                    unless err
                        @log.log "Connection successful"
                    else
                        @log.warn "Connection failed"
                    if @retry-timeout < @max-delay
                        @retry-timeout *= 2
                    # retry the last request (irrespective of err)
                    @request opts, callback
            return
        else if err
            err =
                reason: err.reason
                name: err.name
                message: err.reason or err.error
        if headers?
            if headers['set-cookie']
                @cookie = that
                @trigger \refresh-cookie
        callback err, res, headers

    get-db-info: (callback) ->
        if typeof! callback isnt \Function
            callback = (err, res) ~>
                if err
                    @log.err "Connection failed:", err
                else
                    @log.info "Connection to #{res.db_name} is successful, disk_size
                        : #{parse-int res.disk_size / 1024}K"

        err, res <~ @get null
        if err => return callback err
        callback err, res

    start-heartbeat: ->
        # periodically poll the db so ensure that the cookie stays valid
        # all the time
        <~ :lo(op) ~>
            err, res <~ @get-db-info
            if err
                @log.err "Heartbeat failed: ", err
            else
                size = parse-int res.disk_size / 1024
                size-str = "#{parse-int size} K"
                if size / 1024 > 1
                    size-str = "#{parse-int size / 1024} M"
                @log.info "Heartbeat: #{res.db_name}: #{size-str}"
            <~ sleep 1000ms_per_s * 60s_per_min * 2min
            lo(op)

    connect: (callback) ->
        if typeof! callback isnt \Function then callback = (->)
        err, res <~ @get null
        if err
            console.error "Connection has error:", err
        else
            unless @security-is-okay
                @log.log bg-red "You MUST create the '_security' document in your db."
                throw "Insecure DB!"

            @trigger \connected
            console.log "-----------------------------------------"
            console.log "Connection to #{res.db_name} is successful, disk_size
                : #{parse-int res.disk_size / 1024}K"
            console.log "-----------------------------------------"

        callback err, res

    _connect: (callback) ->
        @security-is-okay = yes

        if typeof! callback isnt \Function then callback = (->)
        @log.log "Authenticating as #{@username}"
        @cookie = null
        err, body, headers <~ @db.auth @username, @password
        if err
            @trigger \error, err

        if headers
            if headers['set-cookie']
                # connection is successful
                @cookie = that
        callback err

    invalidate: ->
        # Debug Start
        # make cookie a garbage, thus break the session
        @log.log "DEBUG MODE: will break connection by invalidating the cookie"
        @cookie = "something-obviously-not-a-valid-cookie"
        @log.log "DEBUG MODE: connection should be broken by now."

    put: (doc, callback) ->
        @request do
            db: @db-name
            body: doc
            method: \post
            , callback

    bulk-docs: (docs, opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        @request do
            db: @db-name
            path: '_bulk_docs'
            body: {docs}
            method: \post
            qs: opts
            , callback

    get: (doc-id, opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        @request do
            db: @db-name
            doc: doc-id
            qs: opts
            , callback

    all-docs: (opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        err, res, headers <~ @request do
            db: @db-name
            path: '_all_docs'
            qs: opts

        callback err, res?.rows

    view: (ddoc-viewname, opts, callback) ->
        # usage:
        #    view 'graph/tank', {my: option}, callback
        #    view 'graph/tank', callback

        # ------------------------------------
        # normalize parameters
        # ------------------------------------
        [ddoc, viewname] = split '/', ddoc-viewname
        if typeof! opts is \Function
            callback = opts
            opts = {}

        err, res, headers <~ @_view ddoc, viewname, {type: \view}, opts

        callback err, (res?rows or [])

    _view: (ddoc, viewName, meta, qs, callback) ->
        relax = @request
        dbName = @db-name
        ``
        var view = function (ddoc, viewName, meta, qs, callback) {
          if (typeof qs === 'function') {
            callback = qs;
            qs = {};
          }
          qs = qs || {};

          var viewPath = '_design/' + ddoc + '/_' + meta.type + '/'  + viewName;

          // Several search parameters must be JSON-encoded; but since this is an
          // object API, several parameters need JSON endoding.
          var paramsToEncode = ['counts', 'drilldown', 'group_sort', 'ranges', 'sort'];
          paramsToEncode.forEach(function(param) {
            if (param in qs) {
              if (typeof qs[param] !== 'string') {
                qs[param] = JSON.stringify(qs[param]);
              } else {
                // if the parameter is not already encoded, encode it
                try {
                  JSON.parse(qs[param]);
                } catch(e) {
                  qs[param] = JSON.stringify(qs[param]);
                }
              }
            }
          });

          if (qs && qs.keys) {
            var body = {keys: qs.keys};
            delete qs.keys;
            return relax({
              db: dbName,
              path: viewPath,
              method: 'POST',
              qs: qs,
              body: body
            }, callback);
          } else {
            var req = {
              db: dbName,
              method: meta.method || 'GET',
              path: viewPath,
              qs: qs
            };

            if (meta.body) {
              req.body = meta.body;
            }

            return relax(req, callback);
          }
        }
        ``
        view(ddoc, viewName, meta, qs, callback)

    get-attachment: (doc-id, att-name, opts, callback) ->
        if typeof opts is \function
            callback = opts
            opts = {}

        @request do
            db: @db-name
            doc: doc-id
            qs: opts
            att: encodeURI attName
            encoding: null
            dontParse: true
            , callback


    follow: (opts, callback) ->
        # follow changes
        # https://www.npmjs.com/package/cloudant-follow
        if typeof! opts is \Function
            callback = opts
            opts = {}

        <~ :lo(op) ~>
            return op! if @connected
            <~ sleep 2000ms
            lo(op)

        default-opts =
            db: "#{@cfg.url}/#{@db-name}"
            headers:
                'X-CouchDB-WWW-Authenticate': 'Cookie'
                cookie: @cookie
            feed: 'continuous'
            since: 'now'

        options = default-opts `merge` opts
        feed = new follow.Feed options
        # "include_rows" workaround
        <~ :lo(op) ~>
            if options.view and options.include_rows
                #@log.log "including row"
                feed.include_docs = yes
                [ddoc-name, view-name] = options.view.split '/'
                err, res <~ @get "_design/#{ddoc-name}"
                #console.log res.javascript
                options.view-function = (doc) ->
                    emit = (key, value) ->
                        {id: doc._id, key, value}
                    view = eval res.javascript .views[view-name]['map']
                    return view doc
                return op!
            else
                return op!

        @log.log "___feeding #{options.view or '/'}"
        feed
            ..on \change, (changes) ~>
                if options.view-function
                    changes.row = that changes.doc
                    delete changes.doc unless opts.include_docs
                callback changes

            ..on \error, (error) ~>
                @log.err "error is: ", error
                @log.debug "We have an error, re-following."
                feed.follow!

            ..follow!

        @on \refresh-cookie, ~>
            @log.debug "Cookie is refreshed. We will re-follow!"
            feed.follow!

    get-all-views: (callback) ->
        views = []
        err, res <~ @all-docs {startkey: "_design/", endkey: "_design0", +include_docs}
        unless err
            for res
                name = ..id.split '/' .1
                continue if name is \autoincrement
                #@log.log "all design documents: ", ..doc
                for let view-name of eval ..doc.javascript .views
                    views.push "#{name}/#{view-name}"
        callback err, views
