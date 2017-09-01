require! '../actor': {Actor}
require! 'colors': {bg-green, bg-red, green, yellow, bg-yellow}
require! 'aea':{sleep, pack, CouchNano}
require! 'prelude-ls': {keys}
require! './couch-helpers': {pack-id}


export class CouchDcsServer extends Actor
    (@params) ->
        super \couch-bridge

        @db = new CouchNano @params

        @on \data, (msg) ~>
            @log.log "received data: #{pack keys msg.payload} from ctx: #{pack msg.ctx}"
            # `put` message
            if \put of msg.payload
                doc = msg.payload.put
                <~ :lo(op) ~>
                    # handle autoincrement values here.
                    if (typeof! doc._id is \Array) and doc._id.1 is \AUTOINCREMENT
                        err, res <~ @db.view "autoincrement/#{doc.type}", do
                            descending: yes
                            limit: 1

                        if err
                            return @send-and-echo msg, {err: err, res: null}

                        next-id = try
                            res.rows.0.key .1 + 1
                        catch
                            0

                        doc._id = pack-id [doc.type, next-id]
                        console.log "+++ new doc id: ", doc._id
                        return op!
                    else
                        return op!

                # add server side keys
                doc.timestamp = Date.now!
                doc.owner = msg.ctx.user unless doc.owner

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
                @log.log "get attachment message received", pack msg.payload
                q = msg.payload.getAtt
                err, res <~ @db.get-attachment q.doc-id, q.att-name, q.opts
                @send-and-echo msg, {err: err, res: res or null}
                
            else
                err = reason: "Unknown method name: #{pack msg.payload}"
                @send-and-echo msg, {err: err, res: null}

        @log.log green "connecting to database..."
        err, res <~ @db.connect
        if err
            @log.log bg-red "Problem while connecting database: ", err
        else
            @log.log bg-green "Connected to database."
            @subscribe "db.**"

    send-and-echo: (orig, _new) ->
        @log.log "sending topic: #{orig.topic} (#{pack _new .length} bytes) "
        @log.log "error was : #{pack _new.err}" if _new.err
        @send-response orig, _new
