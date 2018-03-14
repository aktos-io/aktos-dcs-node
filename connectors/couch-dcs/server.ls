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
                    @log.log (bg-red "Disconnected..."), err

            ..connect!

            ..once \connected, ~>
                @db
                    ..follow (change) ~>
                        @log.log "** publishing change on database:", change.id
                        for let topic in @subscriptions
                            @send "#{topic}.changes.all", change

                    '''
                    ..all-docs {startkey: "_design/", endkey: "_design0", +include_docs}, (err, res) ~>
                        # follow every single view separately
                        for res
                            name = ..id.split '/' .1
                            continue if name is \autoincrement
                            #@log.log "all design documents: ", ..doc
                            for let view-name of eval ..doc.javascript .views
                                view = "#{name}/#{view-name}"
                                @log.log "following view: #{view}"
                                @db.follow {view}, (change) ~>
                                    @log.log "..publishing view change on #{view}", change.id
                                    for let topic in @subscriptions
                                        @send "#{topic}.changes.view.#{view}", change
                    '''

        get-next-id = (doc, callback) ~>
            unless doc._id
                return callback err={reason: "document must have and _id field"}, null

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
                    return callback err

                next-id = try
                    res.0.key .1 + 1
                catch
                    1
                doc._id = "#{prefix}#{next-id}"
                @log.log bg-blue "+++ new doc id: ", doc._id
                return callback err=no, doc
            else
                return callback err=no, doc

        transaction-count = (callback) ~>
            transaction-timeout = 10_000ms
            err, res <~ @db.view "transactions/ongoing", {startkey: Date.now! - transaction-timeout, endkey: {}}
            count = (try res.0.value) or 0
            @log.log "total ongoing transaction: ", count
            callback count

        @on \data, (msg) ~>
            #@log.log "received payload: ", keys(msg.payload), "from ctx:", msg.ctx
            # `put` message
            if msg.payload.put?.type is \transaction
                # handle the transaction
                '''
                Transaction follows this path:

                  1. (Roundtrip 1) Check if there is an ongoing transaction. Fail if there is any.
                  2. (Roundtrip 2) If there is no ongoing transaction, mark the transaction document as 'ongoing' and save
                  3. (Roundtrip 3) At this step, there should be only 1 ongoing transaction. Fail if there are more than 1 ongoing
                    transaction. (More than 1 ongoing transaction means more than one process checked and saw no
                    ongoing transaction at the same time, and then put their ongoing transaction files concurrently)
                  4. (Roundtrip 4 - Rollback Case) Perform any business logic here. If any stuff can't be less than zero or something like that, fail.
                    Mark the transaction document state as `failed` (or something like that) to clear it from ongoing transactions
                    list (to prevent performance impact of waiting transaction timeouts). This step is optional and there is
                    no problem if it fails.
                  5. (Roundtrip 4 - Commit Case) If everything is okay, mark transaction document state as 'done'.

                This algorithm uses the following views:

                        # _design/transactions
                        views:
                            ongoing:
                                map: (doc) ->
                                    if (doc.type is \transaction) and (doc.state is \ongoing)
                                        emit doc.timestamp, 1

                                reduce: (keys, values) ->
                                    sum values

                            balance:
                                map: (doc) ->
                                    if doc.type is \transaction and doc.state is \done
                                        emit doc.from, (doc.amount * -1)
                                        emit doc.to, doc.amount

                                reduce: (keys, values) ->
                                    sum values
                '''

                @log.log bg-yellow "Handling transaction..."
                doc = msg.payload.put

                # Check if transaction document format is correct
                unless doc.from and doc.to
                    return @send-and-echo msg, {err: "Missing source or destination", res: res or null}
                @log.log "transaction doc is: ", doc

                # Check if there is any ongoing transaction (step 1)
                count <~ transaction-count
                if count > 0
                    @log.err bg-red "There is an ongoing transaction, giving up"
                    return @send-and-echo msg, {err: "Ongoing transaction exists", res: null}

                # Put the ongoing transaction file to the db (step 2)
                doc <<<< do
                    state: \ongoing
                    timestamp: Date.now!

                err, res <~ @db.put doc
                if err
                    return @send-and-echo msg, {err: err, res: res or null}

                # update the document
                doc <<<< {_id: res.id, _rev: res.rev}

                # Ensure that there is no concurrent ongoing transactions (step 3)
                count <~ transaction-count
                if count > 1
                    return @send-and-echo msg, {err: "There are more than one ongoing?", res: res or null}

                # Perform the business logic, rollback actively if needed. (step 4)
                <~ :lo(op) ~>
                    if doc.from isnt \outside
                        # stock can not be less than zero
                        err, res <~ @db.view 'transactions/balance', {key: doc.from}
                        curr-amount = (try res.0.value) or 0
                        if doc.amount > curr-amount
                            err = "#{doc.from} can not be < 0 (curr: #{curr-amount}, wanted: #{doc.amount})"
                            @send-and-echo msg, {err, res: null}
                            doc.state = \failed
                            err, res <~ @db.put doc
                            if err => @log.warn "Failed to actively rollback. This will cause performance impacts."
                            @log.log bg-yellow "Transaction ROLLED BACK."
                            return
                        else
                            return op!
                    else
                        return op!

                # Commit the transaction (step 5)
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
                    return @send-and-echo msg, {err: "Empty document", res: null}


                # add server side properties
                # ---------------------------
                i = 0; _limit = docs.length - 1
                <~ :lo(op) ~>
                    err, doc <~ get-next-id docs[i]
                    if err
                        return @send-and-echo msg, {err: err, res: null}

                    # FIXME: "Set unless null" strategy can be hacked in the client
                    # (client may set it to any value) but the original value is kept
                    # in the first revision . Fetch the first version on request.
                    unless doc.timestamp
                        doc.timestamp = Date.now!

                    unless doc.owner
                        doc.owner = if msg.ctx => that.user else \_process

                    docs[i] = doc
                    return op! if ++i > _limit
                    lo(op)

                if docs.length is 1
                    err, res <~ @db.put docs.0
                    @send-and-echo msg, {err: err, res: res or null}
                else
                    err, res <~ @db.bulk-docs docs

                    if typeof! res is \Array and not err
                        for res
                            if ..error
                                err = {error: 'couchdb error'}
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
                    unless err
                        if res and not empty res
                            response.push [..doc for res]
                    else
                        error := err
                    return op!

                response := flatten response
                unless multiple
                    response := response.0
                @send-and-echo msg, {error, res: response}


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
