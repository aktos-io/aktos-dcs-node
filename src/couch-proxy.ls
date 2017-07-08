# -------------------------------------------------
require! './actor': {Actor}
require! './signal': {Signal}
require! 'aea': {pack}

export class CouchProxy extends Actor
    (@db-name) ->
        super \CouchProxy
        @get-signal = new Signal!
        @all-signal = new Signal!
        @put-signal = new Signal!
        @view-signal = new Signal!

        @topic = "db.#{@db-name}"
        @subscribe "#{@topic}.**"

        @on \data, (msg) ~>
            if \res of msg.payload
                err = msg.payload.err
                res = msg.payload.res

                # `get` message
                if msg.topic is "#{@topic}.get"
                    @get-signal.go err, res

                # `all` message
                else if msg.topic is "#{@topic}.all"
                    @all-signal.go err, res

                # `put` message
                else if msg.topic is "#{@topic}.put"
                    @put-signal.go err, res

                # `view` message
                else if msg.topic is "#{@topic}.view"
                    @view-signal.go err, res

                else
                    @log.err "unknown msg topic"


    get: (doc-id, callback) ->
        @send {get: doc-id}, "#{@topic}.get"
        reason, err, res <~ @get-signal.wait 5_000ms
        err = {reason: \timeout} if reason is \timeout
        callback err, res

    all: (opts, callback) ->
        @send {all: opts}, "#{@topic}.all"
        reason, err, res <~ @all-signal.wait 5_000ms
        err = {reason: \timeout} if reason is \timeout
        callback err, res

    put: (doc, callback) ->
        @send {put: doc}, "#{@topic}.put"
        reason, err, res <~ @put-signal.wait 5_000ms
        err = {reason: \timeout} if reason is \timeout
        callback err, res

    view: (_view, opts, callback) ->
        [callback, opts] = [opts, {}] if typeof! opts is \Function

        @send {view: _view, opts: opts}, "#{@topic}.view"
        reason, err, res <~ @view-signal.wait 5_000ms
        err = {reason: \timeout} if reason is \timeout
        callback err, res
