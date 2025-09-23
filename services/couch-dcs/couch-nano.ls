require! 'prelude-ls': {flatten, join, split, compact}
require! 'nano'
require! 'colors': {bg-red, bg-green, bg-yellow, bg-blue}
require! '../../lib': {Logger, sleep, pack, EventEmitter, merge, clone}
require! 'cloudant-follow': follow
require! '../../src/signal': {Signal}
require! 'request'
require! '../../lib/promisify': {upgrade-promisify}

UNAUTHORIZED = 401
FORBIDDEN = 403

export class CouchNano extends EventEmitter
    """
    Configuration: 

        new CouchNano {
            url: http://1.2.3.4:5984 # The database URL 
            user:
                name: couchdb_user_name
                password: couchdb_user_password
            database: the_database_name # Optional. If omitted, you must use .set-db(name) before every request.
        }

    Events:

        * connected
        * disconnected
        * refresh-cookie
        * error

    """
    (@cfg) ->
        super!
        @log = new Logger "db:#{@cfg.user.name}"
        @username = @cfg.user.name
        @password = @cfg.user.password
        @db-name = @cfg.database
        unless @cfg.database
            @_database_name_should_be_provided_everytime = true 
        @db = nano {url: @cfg.url, parseUrl: no}
        @connection = new Signal!
        @first-connection-made = no
        @connecting = no

        @on \connected, ~>
            @connection.go!
            @connected = yes
            @retry-timeout = 100ms
            @first-connection-made = yes
            @connecting = no
            #console.log "couch-nano says: connected"

        @on \disconnected, ~>
            @connected = no
            @connecting = no
            #console.log "couch-nano says: disconnected!"

        @retry-timeout = 100ms
        @max-delay = 12_000ms


    request: (opts, callback) ~>
        opts.headers = {} unless opts.headers
        opts.headers['X-CouchDB-WWW-Authenticate'] = 'Cookie'
        opts.headers.cookie = @cookie

        unless typeof! callback is \Function => callback = (->)

        err, res, headers <~ @db.request opts
        if (err?.statusCode in [UNAUTHORIZED, FORBIDDEN]) or err?code is 'ECONNREFUSED'
            if @first-connection-made
                @trigger \disconnected, {err}
            @log.info "Retrying connection because:", (err.reason or err.description)
            sleep @retry-timeout, ~>
                unless @connecting
                    @connecting = yes
                    @log.info "Retrying connection..."
                    @_connect (err) ~>
                        unless err
                            @log.success "Connection successful"
                        else
                            @log.warn "Connection failed"
                        if @retry-timeout < @max-delay
                            @retry-timeout *= 2
                        # retry the last request (irrespective of err)
                        @request opts, callback
                else
                    #@log.debug "Retrying without connecting..."
                    # TODO: Cleanup Me
                    if @retry-timeout < @max-delay
                        @retry-timeout *= 2
                    # retry the last request (irrespective of err)
                    opts.headers = {}
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

        if @_database_name_should_be_provided_everytime
            @set-db null 

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
        heartbeat-failed = false 
        <~ :lo(op) ~>
            err, res <~ @get-db-info
            if err
                @log.err "Heartbeat failed: ", err
                heartbeat-failed = true 
            else
                if heartbeat-failed 
                    @log.success "Heartbeat succeeded."
                    heartbeat-failed = false 
                size = parse-int res.disk_size / 1024
                size-str = "#{parse-int size} K"
                if size / 1024 > 1
                    size-str = "#{parse-int size / 1024} M"
                #@log.info "Heartbeat: #{res.db_name}: #{size-str}"
            <~ sleep 1000ms_per_s * 60s_per_min * 2min
            lo(op)

    connect: (callback) ->
        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        err, res <~ @get null
        if err
            @log.error "Connection has error:", err
        else
            @trigger \connected
            console.log "-----------------------------------------"
            console.log "Connection to #{res.db_name} is successful, disk_size
                : #{parse-int res.disk_size / 1024}K"
            console.log "-----------------------------------------"

        callback err, res

    check-security: (db-name) -> 
        db-name = db-name or @db-name

        unless db-name => return @log.log "Database name is required to check _security."

        err, res, headers <~ @db.request {            
            db: db-name
            doc: '_security'
        }
        if err?code is 'ECONNREFUSED'
            return @log.log "Connection is refused, could not check _security"

        unless (err?.statusCode in [UNAUTHORIZED, FORBIDDEN]) 
            throw new Error "#{db-name}/_security document is not properly configured!" 
        else 
            @log.success "All good with #{db-name}/_security"

    login: (callback) -> 
        @_connect callback

    get-all-dbs: (opts, callback) -> 
        # https://docs.couchdb.org/en/stable/api/server/common.html#get--_all_dbs
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        @request do
            path: '_all_dbs'
            method: \get
            qs: opts
            , callback

    _connect: (callback) ->
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
                @trigger \refresh-cookie

        callback err

    set-db: (database-name) -> 
        @db-name = database-name

    invalidate: ->
        # Debug Start
        # make cookie a garbage, thus break the session
        @cookie = "something-obviously-not-a-valid-cookie"

    put: (doc, callback) ->
        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        unless @db-name => return callback error="Database name is required."

        @request do
            db: @db-name
            body: doc
            method: \post
            , callback

    # http://docs.couchdb.org/en/latest/api/document/common.html#delete--db-docid
    delete: (docName, rev, callback) -> 
        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted
        unless docName?
            return callback "Document name is required."

        unless @db-name => return callback error="Database name is required."

        @request do
            db: @db-name
            doc: docName
            method: \DELETE
            qs: { rev }
            , callback

    bulk-docs: (docs, opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted
        unless @db-name => return callback error="Database name is required."

        @request do
            db: @db-name
            path: '_bulk_docs'
            body: {docs}
            method: \post
            qs: opts
            , callback

    get: (doc-id, opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted
        unless @db-name => return callback error="Database name is required."

        @request do
            db: @db-name
            doc: doc-id
            qs: opts
            , callback

    find: (query, callback) -> 
        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted
        unless @db-name => return callback error="Database name is required."

        @request do
            db: @db-name
            path: '_find'
            method: 'post'
            body: query
            , callback

    all-docs: (opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted
        unless @db-name => return callback error="Database name is required."

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
        try
            [ddoc, viewname] = split '/', ddoc-viewname
        catch
            @log.debug "We have an error in @view: ", e
            @log.debug "...view name: ", ddoc-viewname
            if callback?
                return callback e, null
            else 
                return Promise.reject e

        if typeof! opts is \Function
            callback = opts
            opts = {}

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        err, res, headers <~ @_view ddoc, viewname, {type: \view}, opts

        callback err, (res?rows or [])

    _view: (ddoc, viewName, meta, qs, callback) ->
        unless @db-name => return callback error="Database name is required."

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

        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted
        unless @db-name => return callback error="Database name is required."

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

        unless @db-name => return callback error="Database name is required."

        j = request.jar!
        default-opts =
            db: "#{@cfg.url}/#{@db-name}"
            headers:
                'X-CouchDB-WWW-Authenticate': 'Cookie'
                cookie: 'somegarbage'
            feed: 'continuous'
            since: 'now'
            http-agent:
                jar: j

        do update-cookie = ~>
            try
                unless @cookie?
                    throw new Error "No cookie found."
                cookie = request.cookie @cookie.0
                j.set-cookie cookie, @cfg.url
            catch
                @log.error "Error while updating cookie for follow.js: ", e

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

        #@log.log "___feeding #{options.view or '/'}"
        feed
            ..on \change, (changes) ~>
                if options.view-function
                    changes.row = that changes.doc
                    delete changes.doc unless opts.include_docs
                callback changes

            ..on \error, (error) ~>
                @log.err "error is: ", error

        @on \refresh-cookie, ~>
            #@log.debug "Cookie is refreshed. We should be still able to follow."
            update-cookie!

        if @cookie?.0?
            update-cookie!

        feed.follow!

    get-all-views: (callback) ->
        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        views = []
        err, res <~ @all-docs {startkey: "_design/", endkey: "_design0", +include_docs}
        unless err
            for res or []
                try
                    name = ..id.split '/' .1
                    continue if name is \autoincrement

                    if ..doc.language is 'query'
                        for view-name of ..doc.views
                            views.push "#{name}/#{view-name}"
                        continue

                    #@log.log "all design documents: ", ..doc
                    for let view-name of eval ..doc.javascript .views
                        views.push "#{name}/#{view-name}"
                catch
                    @log.err "Something went wrong with ", .., e

        callback err, compact views

    update-all-views: (callback) ->
        callback <~ upgrade-promisify callback # returns a promise if "callback" is omitted

        error = null
        err, views <~ @get-all-views
        if views.length is 0
            return callback "No views can be found."
        i = 0
        <~ :lo(op) ~>
            name = views[i]
            #@log.info "...updating view: #{name}"
            err, res <~ @view name, {limit: 1}
            return op! if ++i is views.length
            lo(op)
        callback error
