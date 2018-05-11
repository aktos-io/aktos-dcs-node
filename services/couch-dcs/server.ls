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


/*------------------------------------------------------------------------------

Topic is calculated (and validated) in the following way:

    1. selector =
        prefix
        + doc.type or view name (kind of filter function)
        + method (get, put, view, change, etc...)
        + filter function
        + ...more filter functions
    2. find the best match in the opts.permissions with
        "#{prefix}.#{method}.#{doc-type or view-name}.**"
    3. use that match as the message topic.

Example selector:

    db.order.get -> db.order.get.full
    db.order.put
        # => put a document as is if its "type is order"
    db.order.put.as-client
        # => put a document if its type is order and passed through
        "as-client" filter
    db.view.orders/getOrders -> db.view.orders/getOrders.match-own-company
        # => filter with "match-company" function
    db.view.orders/getOrders -> db.view.orders/getOrders
        # => get whole view
    db.change.view.orders/getOrders

    Example permissions:

    db.put.order.as-client
    db.*.order.as-client
    db.*.order (which means full access to "type is order" document)


-------------------------------------------------------------------------------*/


export class CouchDcsServer extends Actor
    (@params) ->
        super (@params.name or \CouchDcsServer)

    action: ->
        if @params.subscribe
            @log.log green "Subscribing to #{that}"
            @subscribe that
        else
            @log.warn "No subscriptions provided to #{@name}"

        event-route = @params.subscribe.replace /^@/, ''

        @db = new CouchNano @params
            ..on do
                connected: ~>
                    @log.log bg-green "Connected to database."

                error: (err) ~>
                    @log.log (bg-red "Problem while connecting database: "), err

                disconnected: (err) ~>
                    @log.info "Disconnected from db."

            ..connect!

            /*
            ..follow (change) ~>
                @log.log (bg-green "<<<<<<>>>>>>"), "publishing change on #{@name}:", change.id
                @send "#{event-route}.change.all"
            */

            ..get-all-views (err, res) ~>
                for let view in res
                    @log.log (bg-green "<<<_view_>>>"), "following view: #{view}"
                    @db.follow {view, +include_rows}, (change) ~>
                        topic = "#{event-route}.change.view.#{view}"
                        @log.log (bg-green "<<<_view_>>>"), "..publishing #{topic}", change.id
                        @log.todo "Take authorization into account while publishing changes!"
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
            #@log.log "received payload: ", keys(msg.data), "by:", msg.user
            # `put` message
            if \put of msg.data and msg.data.transaction is on
                # handle the transaction, see ./transactions.md
                @log.log bg-yellow "Handling transaction..."
                doc = msg.data.put

                # insert chain
                <~ :lo(op) ~>
                    chain = \before-transaction
                    if @has-listener chain
                        <~ @trigger chain, msg
                        return op!
                    else
                        return op!


                # Assign proper doc id
                err, next-id <~ get-next-id doc._id
                unless err => doc._id = next-id
                unless doc._rev
                    doc.timestamp = Date.now!
                    doc.owner = (try msg.user) or \_process
                doc.{}meta.modified = Date.now!


                # Step 1: Check if there is any ongoing transaction
                transaction-timeout = 10_000ms
                count <~ transaction-count transaction-timeout
                if count > 0
                    err = "There is an ongoing transaction already, aborting...
                        TODO: DO NOT FAIL IMMEDIATELY, ADD THIS TRANSACTION
                        TO THE QUEUE."
                    return @send-and-echo msg, {err}

                # Step 2: Put the ongoing transaction file to the db
                doc.transaction = \ongoing
                err, res <~ @db.put doc
                if err => return @send-and-echo msg, {err, res}
                doc <<< {_id: res.id, _rev: res.rev}

                if doc._deleted
                    return @send-and-echo msg, {err, res}

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
                    doc.transaction = \failed
                    return @db.put doc, (err, res) ~>
                        if err
                            @log.info "Failed to actively rollback.
                                This will cause performance impacts only."
                        else
                            @log.info "Transaction ROLLED BACK."

                doc.transaction = \done
                err, res <~ @db.put doc
                unless err
                    @log.log bg-green "Transaction completed."
                else
                    @log.err "Transaction is not completed. id: #{doc._id}"

                @send-and-echo msg, {err: err, res: res or null}


            else if \put of msg.data
                msg.data.put = flatten [msg.data.put]
                docs = msg.data.put
                if empty docs
                    return @send-and-echo msg, {err: message: "Empty document", res: null}

                <~ :lo(op) ~>
                    if @has-listener \before-put
                        <~ @trigger \before-put, msg
                        return op!
                    else
                        return op!

                # Apply server side attributes
                # ---------------------------
                i = 0;
                <~ :lo(op) ~>
                    return op! if i > (docs.length - 1)
                    err, next-id <~ get-next-id docs[i]._id
                    unless err
                        docs[i]._id = next-id

                    # FIXME: "Set unless null" strategy can be hacked in the client
                    # (client may set it to any value) but the original value is kept
                    # in the first revision . Fetch the first version on request.
                    unless docs[i]._rev
                        docs[i].timestamp = Date.now!
                        docs[i].owner = (try msg.user) or \_process

                    unless docs[i].timestamp
                        @log.warn "Why don't we have a timestamp???"
                        docs[i].timestamp = Date.now!

                    unless docs[i].owner
                        @log.warn "Why don't we have an owner???"
                        docs[i].owner = (try msg.user) or \_process
                    # End of FIXME

                    docs[i].{}meta.modified = Date.now!
                    i++
                    lo(op)

                # Write to database
                err = null
                res = null
                <~ :lo(op) ~>
                    if docs.length is 1
                        _err, _res <~ @db.put docs.0
                        err := _err
                        res := _res
                        return op!
                    else
                        _err, _res <~ @db.bulk-docs docs
                        err := _err
                        res := _res
                        if typeof! res is \Array and not err
                            for res
                                if ..error
                                    err := {error: message: 'Errors occurred, see the response'}
                                    break
                        return op!
                # send the response
                @send-and-echo msg, {err, res}

            # `get` message
            else if \get of msg.data
                <~ :lo(op) ~>
                    if @has-listener \before-get
                        <~ @trigger \before-get, msg
                        return op!
                    else
                        return op!
                multiple = typeof! msg.data.get is \Array # decide response format
                doc-id = msg.data.get
                doc-id = [doc-id] if typeof! doc-id is \String
                doc-id = doc-id |> unique-by JSON.stringify
                {String: doc-id, Array: older-revs} = doc-id |> group-by (-> typeof! it)
                opts = msg.data.opts or {}
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

                # perform the business logic here
                if @has-listener \get
                    err, res <~ @trigger \get, msg, error, response
                    @send-and-echo msg, {err, res}
                else
                    @send-and-echo msg, {err, res}

            # `all-docs` message
            else if \allDocs of msg.data
                err, res <~ @db.all-docs msg.data.all-docs
                @send-and-echo msg, {err: err, res: res or null}

            # `view` message
            else if \view of msg.data
                #@log.log "view message received", pack msg.data
                <~ :lo(op) ~>
                    if @has-listener \before-view
                        <~ @trigger \before-view, msg
                        return op!
                    else
                        return op!
                err, res <~ @db.view msg.data.view, msg.data.opts
                if @has-listener \view
                    err, res <~ @trigger \view, msg, err, res
                    @send-and-echo msg, {err, res}
                else
                    @send-and-echo msg, {err, res}

            # `getAtt` message (for getting attachments)
            else if \getAtt of msg.data
                @log.log "get attachment message received", msg.data
                @send-response msg, {+part, timeout: 30_000ms, +ack}, null
                q = msg.data.getAtt
                err, res <~ @db.get-attachment q.doc-id, q.att-name, q.opts
                @send-and-echo msg, {err: err, res: res or null}

            else if \cmd of msg.data
                cmd = msg.data.cmd
                @log.warn "got a cmd:", cmd

            else
                err = reason: "Unknown method name: #{pack msg.data}"
                @send-and-echo msg, {err: err, res: null}


    send-and-echo: (orig, _new) ->
        if _new.err
             @log.log "error was : #{pack _new.err}"
        else
            @log.log (green ">>>"), "responding for #{orig.from}, #{orig.seq}:
                #{pack _new .length} bytes"
        @send-response orig, _new
