# Couch DCS

This server and client libraries are created to be able to use CouchDB over DCS network.

In addition to changing transport layer from HTTP to DCS, this library aims to [address some CouchDB limitations](./doc/addressing-couchdb-limitations.md).

## Usage


1. Run `CouchDcsServer` instance on your server:


```ls

new CouchDcsServer do
  user:
    name: 'your-couchdb-username'
    password: 'your-password'
  url: "IP-OR-ADDRESS-OF-YOUR-COUCHDB-INSTANCE" # eg. "http://127.0.0.1:5984"
  database: 'your-db-name'
  subscribe: '@dbuser'                          # DCS route to be subscribed
```

`CouchDcsServer` will handle the default `CouchDcsClient` requests. There are also optional `before-*` and `(after-)*` events. Additional events may be overridden by your `CouchDcsServer` instance. 

* `before-*` Event is triggered before doing anything with the database. This event will send an `ack` (ping back) message to the client by default. 
* `(after-)*` Event is triggered before results are sent to the client. You can override this event in order to manipulate the final results.


Available `before-*` events: `.on \before-get`, `.on \before-put`, `.on \before-transaction`, `.on \before-view`, `.on \before-getAtt`, `.on \before-allDocs`, `.on \before-custom`. 

Available `(after-)*` events: `.on \put`, `.on \get`, `.on \view`, `.on \transaction`


2. Create a `CouchDcsClient` instance use it as if it was a regular CouchDB driver:

```ls
db = new CouchDcsClient {route: '@dbuser'}

console.log "getting the document with 'your-document-id':"
err, res <~ db.get 'your-document-id'
console.log "response is: ", res
```

`err` is a truthy value if there is any kind of problem with the CouchDcsServer
    or CouchDB itself
`res` is the exact response of the request.

### Using CouchDcsClient with `await`
if you omit the callback while calling `.get`, `.put`, `.view`, `.all-docs`, `.put-transaction`, `.get-attachment`, `.follow`, `.observe`; these methods will return a `Promise` that can be used with `await`:

```ls
try
	doc = await db.get 'your-document-id'
catch
	console.log "some error ocurred: ", e
```

3. In order to make it work, ensure that your user have `db.document-type.**` permissions.


`CouchDcsClient` has the following methods:

* `.get docs, [opts, ] callback(err, res)`: Get single or multiple documents from database.
    docs format:
        if `String`: fetch only one document, response is the document itself
        if `Array`: fetch multiple documents, response is an array of documents
            Documents are fetched depending on the array elements.
            Element type:
                `"SOME_ID"` or `["SOME_ID", undefined]`: fetch the latest revision
                `["SOME_ID", "SOME_REV"]`: fetch `"SOME_REV"` revision

* `.put doc, [opts,] callback(err, res)`: Put single document to the database.

* `.put-transaction doc, [opts,] callback(err, res)`:
        1. `on \before-transaction` event is triggered. 
        2. It is guaranteed that no other transaction is being processed. 
        3. `on \transaction` event is triggered. If this event is handled succesfully, the document is considered "committed". `doc.transaction` field is set to `"done"`.
        4. Document is still saved to the database if the `on \transaction` event fails. `doc.transaction` field is set to `"failed"` in this case. 

* `.view 'designName/yourView', [opts, ] callback(err, res)`: Query a view in the database.
* `.all [opts,] callback(err, res)`: Use "allDocs" api of CouchDB.
* `.getAttachment 'document-id', 'attachment-name', callback(err, res)`: Retrieve an attachment from a document.

Callbacks will be called with `error, response` parameters.

# Additional Functionalities

## 1. Create documents with `AUTOINCREMENT`ed ID's

See ./doc/autoincrement.md

## 2. Setting Server Side Attributes

`.timestamp` and `.owner` attributes are set by the server automatically. Custom server side attribute definition will be supported soon.


## 3. `get` recursively

`db.get your_document_id, {recurse: 'some.keypath'}` will fetch the
document with `your_document_id` and the documents with ids that match with
`recurse` keypath.

Checkout [the tests](../../lib/merge-deps.ls) for examples.


# Roadmap/TODO

- [ ] Add document deduplication support
- [ ] Provide a way to resume interrupted downloads/uploads
- [ ] Stream videos directly from database

