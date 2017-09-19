require! '../../src/actor': {Actor}
require! 'colors': {
    bg-green, bg-red, bg-yellow, bg-blue
    green, yellow, blue
}
require! 'aea':{sleep, pack}
require! 'prelude-ls': {keys}
require! './couch-nano': {CouchNano}


export class CouchDcsServer extends Actor
    (@params) ->
        super (@params.name or \CouchDcsServer)

    action: ->
        if @params.subscribe
            @log.log green "Subscribing to #{that}"
            @subscribe that
        else
            @log.warn "No subscriptions provided to #{@name}"

        @db = new CouchNano @params
            ..on do
                connected: ~>
                    @log.log bg-green "Connected to database."

                error: (err) ~>
                    @log.log (bg-red "Problem while connecting database: "), err

                disconnected: (err) ~>
                    @log.log (bg-red "Disconnected..."), err

            ..connect!

        @on \data, (msg) ~>
            @log.log "received data: ", keys(msg.payload), "from ctx:", msg.ctx
            # `put` message
            if \put of msg.payload
                doc = msg.payload.put
                <~ :lo(op) ~>
                    return op! unless doc._id
                    # handle autoincrement values here.
                    autoinc = doc._id.split /#+/
                    if autoinc.length > 1
                        prefix = autoinc.0
                        @log.log "prefix is: ", prefix
                        view-prefix = prefix.split /[^a-zA-Z]+/ .0.to-upper-case!
                        err, res <~ @db.view "autoincrement/short", do
                            descending: yes
                            limit: 1
                            startkey: [view-prefix, {}]
                            endkey: [view-prefix]

                        if err
                            return @send-and-echo msg, {err: err, res: null}

                        next-id = try
                            res.rows.0.key .1 + 1
                        catch
                            1

                        doc._id = "#{prefix}#{next-id}"
                        @log.log bg-blue "+++ new doc id: ", doc._id
                        return op!
                    else
                        return op!

                # add server side properties
                # ---------------------------
                # FIXME: "Set unless null" strategy can be hacked in the client
                # (client may set it to any value) but the original value is kept
                # in the first revision . Fetch the first version on request.
                unless doc.timestamp
                    doc.timestamp = Date.now!

                unless doc.owner
                    doc.owner = if msg.ctx => that.user else \_process

                err, res <~ @db.put doc
                @send-and-echo msg, {err: err, res: res or null}

            # `get` message
            else if \get of msg.payload
                doc-id = msg.payload.get
                opts = msg.payload.opts or {}
                err, res <~ @db.get doc-id, opts
                @send-and-echo msg, {err: err, res: res or null}

            # `all` message
            else if \all of msg.payload
                err, res <~ @db.all msg.payload.all
                @send-and-echo msg, {err: err, res: res or null}

            # `view` message
            else if \view of msg.payload
                @log.log "view message received", pack msg.payload
                err, res <~ @db.view msg.payload.view, msg.payload.opts
                @send-and-echo msg, {err: err, res: (res?.rows or null)}

            # `getAtt` message (for getting attachments)
            else if \getAtt of msg.payload
                @log.log "get attachment message received", msg.payload
                q = msg.payload.getAtt
                err, res <~ @db.get-attachment q.doc-id, q.att-name, q.opts
                @send-and-echo msg, {err: err, res: res or null}

            else
                err = reason: "Unknown method name: #{pack msg.payload}"
                @send-and-echo msg, {err: err, res: null}


    send-and-echo: (orig, _new) ->
        @log.log "sending topic: #{orig.topic} (#{pack _new .length} bytes) "
        @log.log "error was : #{pack _new.err}" if _new.err
        @send-response orig, _new
