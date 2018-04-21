require! '../../src/actor': {Actor}
require! 'colors': {
    bg-green, bg-red, bg-yellow, bg-blue
    green, yellow, blue
}
require! '../../lib': {sleep, pack, clone}
require! 'prelude-ls': {
    keys, values, flatten, empty, unique,
    Obj, difference, union, group-by, unique-by
}
require! './couch-nano': {CouchNano}

dump = (name, doc) ->
    console.log "#{name} :", JSON.stringify(doc, null, 2)


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
                    @log.info "Disconnected from db."

            ..connect!

            ..follow (change) ~>
                @log.log (bg-green "<<<<<<>>>>>>"), "publishing change on #{@name}:", change.id
                for let topic in @subscriptions
                    @send "#{topic}.changes.all", change

            ..get-all-views (err, res) ~>
                for let view in res
                    @log.log (bg-green "<<<_view_>>>"), "following view: #{view}"
                    @db.follow {view, +include_rows}, (change) ~>
                        for let subs in @subscriptions
                            topic = "#{subs}.changes.view.#{view}"
                            @log.log (bg-green "<<<_view_>>>"), "..publishing #{topic}", change.id
                            @send topic, change

            ..start-heartbeat!

        get-next-id = (template, callback) ~>
            # returns the next available `_id`
            # if template format is applicable for autoincrementing, return the incremented id
            # if template format is not correct, return the `_id` as is
            unless template
                return callback err={
                    reason: "No template is supplied for autoincrement"
                    }, null
            # handle autoincrement values here.
            autoinc = template.split /#{4,}/
            if autoinc.length > 1
                @log.log "Getting next id for #{template}"
                prefix = autoinc.0
                @log.log "prefix is: ", prefix
                view-prefix = prefix.split /[^a-zA-Z]+/ .0.to-upper-case!
                err, res <~ @db.view "autoincrement/short", do
                    descending: yes
                    limit: 1
                    startkey: [view-prefix, {}]
                    endkey: [view-prefix]

                if err
                    return callback err

                next-id = try
                    res.0.key .1 + 1
                catch
                    1
                new-doc-id = "#{prefix}#{next-id}"
                @log.log bg-blue "+++ new doc id: ", new-doc-id
                return callback err=no, new-doc-id
            else
                return callback err=no, template

        transaction-count = (timeout, callback) ~>
            # transaction count must be handled by
            date-limit = Date.now! - timeout
            err, res <~ @db.view "transactions/ongoing", {startkey: date-limit, endkey: {}}
            count = (try res.0.value) or 0
            @log.log "total ongoing transaction: ", count
            callback count

        @on \data, (msg) ~>
            #@log.log "received payload: ", keys(msg.payload), "from ctx:", msg.ctx
            # `put` message
            if msg.payload.put?.type is \transaction
                # handle the transaction, see ./transactions.md

                @log.log bg-yellow "Handling transaction..."
                doc = msg.payload.put

                # Assign proper doc id
                err, next-id <~ get-next-id docs[i]._id
                doc._id = next-id unless err
                doc.timestamp = Date.now!
                doc.owner = if msg.ctx => that.user else \_process


                # Step 1: Check if there is any ongoing transaction
                transaction-timeout = 10_000ms
                count <~ transaction-count transaction-timeout
                if count > 0
                    err = "There is an ongoing transaction already, aborting..."
                    return @send-and-echo msg, {err}

                # Step 2: Put the ongoing transaction file to the db
                doc.state = \ongoing
                err, res <~ @db.put doc
                if err => return @send-and-echo msg, {err, res}
                doc <<< {_id: res.id, _rev: res.rev}

                # Step 3: Ensure that there is no concurrent ongoing transactions
                count <~ transaction-count transaction-timeout
                if count > 1
                    err = "There can't be more than one ongoing transaction."
                    return @send-and-echo msg, {err}

                # Step 4: Perform the business logic here
                err <~ @trigger \transaction, @db, doc

                # Step 5: Commit or abort the transaction
                if err
                    @send-and-echo msg, {err}
                    doc.state = \failed
                    return @db.put doc, (err, res) ~>
                        if err
                            @log.info "Failed to actively rollback.
                                This will cause performance impacts only."
                        else
                            @log.info "Transaction ROLLED BACK."

                doc.state = \done
                err, res <~ @db.put doc
                unless err
                    @log.log bg-green "Transaction completed."
                else
                    @log.err "Transaction is not completed. id: #{doc._id}"

                @send-and-echo msg, {err: err, res: res or null}


            else if \put of msg.payload
                docs = flatten [msg.payload.put]
                if empty docs
                    return @send-and-echo msg, {err: message: "Empty document", res: null}

                # Apply server side attributes
                # ---------------------------
                # FIXME: "Set unless null" strategy can be hacked in the client
                # (client may set it to any value) but the original value is kept
                # in the first revision . Fetch the first version on request.
                i = 0;
                <~ :lo(op) ~>
                    return op! if i > (docs.length - 1)
                    err, next-id <~ get-next-id docs[i]._id
                    unless err
                        docs[i]._id = next-id

                    unless docs[i].timestamp
                        docs[i].timestamp = Date.now!
                    unless docs[i].owner
                        docs[i].owner = if msg.ctx => that.user else \_process
                    i++
                    lo(op)

                # Write to database
                if docs.length is 1
                    err, res <~ @db.put docs.0
                    @send-and-echo msg, {err: err, res: res or null}
                else
                    err, res <~ @db.bulk-docs docs

                    if typeof! res is \Array and not err
                        for res
                            if ..error
                                err = {error: message: 'Errors occurred, see the response'}
                                break

                    @send-and-echo msg, {err: err, res: res or null}

            # `get` message
            else if \get of msg.payload
                if msg.payload.opts.custom
                    # this message will be handled custom
                    @trigger \custom-get, @db, msg.payload, (err, res) ~>
                        console.log "...handled by custom handler"
                        @send-and-echo msg, {err, res}
                    return

                multiple = typeof! msg.payload.get is \Array # decide response format
                doc-id = msg.payload.get
                doc-id = [doc-id] if typeof! doc-id is \String
                doc-id = doc-id |> unique-by JSON.stringify
                {String: doc-id, Array: older-revs} = doc-id |> group-by (-> typeof! it)
                opts = msg.payload.opts or {}
                opts.keys = doc-id or []
                opts.include_docs = yes
                #dump 'opts: ', opts
                error = no
                response = []

                # fetch older revisions (if requested)
                # async loop
                index = 0
                <~ :lo(op) ~>
                    return op! if index is older-revs?.length
                    unless older-revs
                        #@log.log bg-yellow "no older-revs is requested"
                        return op!
                    [id, rev] = older-revs[index]
                    unless rev
                        # last revision is requested by undefined rev
                        opts.keys.push id
                        index++
                        lo(op)
                    else
                        @log.log bg-yellow "Older version requested: #{id}"
                        @log.log bg-yellow "rev: ", rev
                        err, res <~ @db.get id, {rev}
                        unless err
                            response.push res
                        else
                            error := err
                        index++
                        lo(op)

                # fetch the latest versions (if requested any)
                <~ :lo(op) ~>
                    if empty opts.keys
                        #@log.log bg-yellow "no doc-id is requested"
                        return op!
                    @log.log "Docs are requested: #{opts.keys.join ', '}"
                    err, res <~ @db.all-docs opts
                    _errors = []
                    unless err
                        if res and not empty res
                            for res
                                if ..doc
                                    response.push ..doc
                                if ..error
                                    _errors.push ..
                    else
                        error := err

                    if not error and not empty _errors
                        error := _errors
                    return op!

                response := flatten response
                unless multiple
                    response := response?.0
                    error := error?.0
                @send-and-echo msg, {err: error, res: response}


            # `all-docs` message
            else if \allDocs of msg.payload
                err, res <~ @db.all-docs msg.payload.all-docs
                @send-and-echo msg, {err: err, res: res or null}

            # `view` message
            else if \view of msg.payload
                @log.log "view message received", pack msg.payload
                err, res <~ @db.view msg.payload.view, msg.payload.opts
                @send-and-echo msg, {err: err, res: (res or null)}

            # `getAtt` message (for getting attachments)
            else if \getAtt of msg.payload
                @log.log "get attachment message received", msg.payload
                q = msg.payload.getAtt
                err, res <~ @db.get-attachment q.doc-id, q.att-name, q.opts
                @send-and-echo msg, {err: err, res: res or null}

            else if \cmd of msg.payload
                cmd = msg.payload.cmd
                @log.warn "got a cmd:", cmd

            else if \follow of msg.payload
                @log.warn "DEPRECATED: follow message:", msg.payload
                return

            else
                err = reason: "Unknown method name: #{pack msg.payload}"
                @send-and-echo msg, {err: err, res: null}


    send-and-echo: (orig, _new) ->
        if _new.err
             @log.log "error was : #{pack _new.err}"
        else
            @log.log (green ">>>"), "responding for #{orig.topic}: #{pack _new .length} bytes"
        @send-response orig, _new
