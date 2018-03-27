# Addressing CouchDB Limitations

## How to create incremental document `id`s: 

1. Design your document ids something like: `{_id: mytype/1, ...}` 
2. Create a view that returns the numeric part of the document 
3. Before creating a new document, get the greatest document id with the view.
4. Increment the id by 1
5. Try to put the document. 
6. If you get `401`, go to step 3.


## How to add owner, timestamp, etc. to the document

Use a microservice that resides between the actual application and the database, add timestamp and document owner at this step. 

## How to make a transaction

TODO: https://en.wikipedia.org/wiki/Two-phase_commit_protocol

Set your document's `type: 'transaction'` and let the `CouchDcsServer` handle the rest. Algorithm is [explained in the source code](https://github.com/aktos-io/aktos-dcs-node/blob/3961aa9f0a5b5f0db0ca1d429f5f5b2d4baa16bc/connectors/couch-dcs/server.ls#L110-L146).
