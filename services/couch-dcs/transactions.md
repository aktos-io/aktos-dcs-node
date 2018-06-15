# Transaction Algorithm

Transaction follows this path:

  1. (Roundtrip 1) Check if there is an ongoing transaction. Fail if there is any.
  2. (Roundtrip 2) If there is no ongoing transaction, mark the transaction document as 'ongoing' and save
  3. (Roundtrip 3) At this step, there should be only 1 ongoing transaction. Fail if there are more than 1 ongoing
    transaction. (More than 1 ongoing transaction means more than one process checked and saw no
    ongoing transaction at the same time, and then put their ongoing transaction files concurrently)
  4. (Roundtrip 4) Perform any business logic here. If any stuff can't be less than zero or something like that,
    make the transaction fail.
  5. (Roundtrip 5 - Commit or Rollback) Mark the transaction document state as `failed`
    (or something like that, other than "done" or "ongoing") to clear it from ongoing
    transactions list (which is for preventing performance impact of waiting
    transaction timeouts). If rollback is failed (or skipped), nothing bad will
    happen except for the remaining timeout delay for the next transactions.

    If everything is okay, mark transaction document state as 'done' to
    commit.

This algorithm uses the following view:


    # _design/transactions
    views:
        ongoing:
            map: (doc) ->
                if (doc.type is \transaction) and (doc.state is \ongoing)
                    emit doc.timestamp, 1

            reduce: (keys, values) ->
                sum values
