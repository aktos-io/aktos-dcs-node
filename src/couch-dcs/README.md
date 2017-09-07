# Couch DCS

This server and client libraries are created to be able to use CouchDB over DCS network.

In addition to changing transport layer from HTTP to DCS, this library aims to [address some CouchDB limitations](./addressing-couchdb-limitations.md).

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

### Create documents with `AUTOINCREMENT`ed ID's

Suppose you will save documents with type `foo` by autoincrementing the ID field. Follow the steps:

1. Create a view with name `any` in `autoincrement` design document for the first time:

    In Livescript:

    ```ls
    views:
        any:
            map: (doc) ->
                parts = doc._id.split '-'
                id = parse-int parts.splice -1, 1  # use last portion as ID
                type = parts.join '-'  # use first parts as type
                if type is doc.type
                    emit [type, id], null                
    ```

    or in Javascript:

    ```js
    views: {
        any: {
            map: function(doc){
                var parts, id, type;
                parts = doc._id.split('-');
                id = parseInt(parts.splice(-1, 1));
                type = parts.join('-');
                if (type === doc.type) {
                    return emit([type, id], null);
                }
            }
        }
    }
    ```

2. Set your document `_id` to `AUTOINCREMENT`:

```js
{
    _id: 'AUTOINCREMENT',
    type: 'foo',
    hello: 'there'
}
```

3. Save your document with `CouchDcsClient.put` method. Your document id will be something like `foo-1358`

### Troubleshooting

To verify that your view returns the correct ID, use the following filter to get latest ID:

```
http://example.com/yourdb/_design/autoincrement/_view/any?descending=true&startkey=["foo",{}]&endkey=["foo"]
```

# Roadmap 

- [ ] Add document deduplication support 
- [ ] Provide a way to resume interrupted downloads/uploads 
- [ ] Stream videos directly from database
