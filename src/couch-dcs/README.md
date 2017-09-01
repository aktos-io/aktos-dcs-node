# Couch DCS

This server and client libraries are created to be able to use CouchDB over DCS network. 

In addition to changing transport layer from HTTP to DCS, this library aims to [address CouchDB limitations](./addressing-couchdb-limitations.md). 

## Usage


1. Run `CouchDcsServer` instance on your server: 


```ls 

new CouchDcsServer do 
  user:
    name: 'your-couchdb-username'
    password: 'your-password'
  url: "IP-OR-ADDRESS-OF-YOUR-COUCHDB-INSTANCE"
  database: 'your-db-name'
```

2. Create a `CouchDcsClient` instance use it as if it was a regular CouchDB driver: 

```ls 
db = new CouchDcsClient 'document-type'

console.log "getting the document with 'your-document-id':"
err, res <~ db.get 'your-document-id'
console.log "response is: ", res 
```

3. In order to make it work, ensure that your user have `db.document-type.**` permissions. 

# API

`CouchDcsClient` has the following API:

* `.get 'document-id', [opts, ] callback`
* `.put doc, callback`
* `.view 'designName/yourView', [opts, ] callback`
* `.all callback`
* `.getAttachment 'document-id', 'attachment-name', callback`

Callbacks will be called with `error, response` parameters. 

# Additional Functionalities

## Create documents with `AUTOINCREMENT`ed ID's

Suppose you will save documents with type `foo` by autoincrementing the ID field. Follow the steps:

1. Create `foo` view in `autoincrement` design document: 

    ```ls
    views:
        foo:
            map: (doc) ->
                if doc.type is 'foo' 
                    arr-id = doc._id.split '/'
                    emit [arr-id.0, parse-int(arr-id.1)], null
    ```

2. Create your document with `_id: ['foo', 'AUTOINCREMENT']` id, instead of a regular `String`. 

3. Save your document with `CouchDcsClient.put`. 
