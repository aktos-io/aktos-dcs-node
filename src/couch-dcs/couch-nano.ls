require! 'prelude-ls': {flatten, join, split}
require! 'nano'
require! 'colors': {bg-red, bg-green, bg-yellow, bg-blue}
require! 'aea': {sleep, pack, logger, EventEmitter}

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
        @log = new logger "db:#{@cfg.database}"
        @username = @cfg.user.name
        @password = @cfg.user.password
        @db-name = @cfg.database
        @db = nano url: @cfg.url

    request: (opts, callback) ~>
        opts.headers = {} unless opts.headers
        opts.headers['X-CouchDB-WWW-Authenticate'] = 'Cookie'
        opts.headers.cookie = @cookie

        #console.log "request opts : ", opts
        err, res, headers <~ @db.request opts
        if err => if err.statusCode is 401
            @trigger \disconnected, {err}
            @connect (err) ~>
                unless err
                    @trigger \connected
                    @request opts, callback
            return

        if headers?
            if headers['set-cookie']
                @cookie = that
                @trigger \refresh-cookie

        err = {reason: err.reason, name: err.name, message: err.reason} if err
        callback err, res, headers

    connect: ->
        callback = (->) if typeof! callback isnt \Function
        @log.log "Authenticating as #{@username}"
        @cookie = null
        err, body, headers <~ @db.auth @username, @password
        if err
            @trigger \error, err
            return

        if headers
            if headers['set-cookie']
                # connection is successful
                @cookie = that
                @trigger \connected
                return

        @trigger \error, {text: "unexpected response"}

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

    get: (doc-id, opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        @request do
            db: @db-name
            doc: doc-id
            qs: opts
            , callback

    all: (opts, callback) ->
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

        callback err, res

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
            att: attName
            encoding: null
            dontParse: true
            , callback
