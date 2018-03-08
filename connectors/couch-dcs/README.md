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

* `.get docs, [opts, ] callback(err, res)`
    docs format:
        if `String`: fetch only one document, response is the document itself
        if `Array`: fetch multiple documents, response is an array of documents
            Documents are fetched depending on the array elements.
            Element type:
                `"SOME_ID"`: fetch the latest revision
                `["SOME_ID", "SOME_REV"]`: fetch `"SOME_REV"` revision
                `["SOME_ID", undefined]`: fetch the latest version

* `.put doc, callback(err, res)`
* `.view 'designName/yourView', [opts, ] callback(err, res)`
* `.all callback(err, res)`
* `.getAttachment 'document-id', 'attachment-name', callback(err, res)`

Callbacks will be called with `error, response` parameters.

# Additional Functionalities

## 1. Create documents with `AUTOINCREMENT`ed ID's

Suppose you will save documents by autoincrementing the ID field. Follow the steps:

### 1. Setup

Create a view with name `short` in `autoincrement` design document in your db:

```ls
views:
    short:
        map: (doc) ->
            prefix = doc._id.split /[0-9]+/ .0
            if prefix
                seq = if doc._id.split prefix .1 => parse-int that else 0
                prefix = prefix.split /[^a-zA-Z]+/ .0.to-upper-case!
                emit [prefix, seq], null
```


### Creating a document

1. If you want to assign an autoincremented ID, append '#' character to your document's `_id`  field:

```js
{
    _id: 'foo-####',
    type: 'bar',
    hello: 'there'
}
```

2. Save your document with `CouchDcsClient.put` method, as usual.

Your document id will be something like `foo-1358`

### Notes

1. *On save*: Your prefix is calculated by splitting right before first '#'
character and grabbing left side of the result.

| Autoincrement ID | Calculated Prefix | Example ID |
| ---- | ----- | ---- |
| `foo###` | `foo` | `foo1234` |
| `foo-###` | `foo-` | `foo-1234` |
| `Foo-###` | `Foo-` | `Foo-1234` |

2. *On calculating next ID*: Current biggest ID is calculated by splitting right before any alphanumeric characters, grabbing left side, converting to upper case.

For example, we have `foo-5` in the database. Following autoincremented IDs will be assigned for the IDs:

| Seq. | Provided `doc._id` | Saved as |
| ---- | ----- | ----- |
| 1 | `foo-#` | `foo-6` |
| 2 | `foo-#` | `foo-7` |
| 3 | `foo#`  | `foo8`
| 4 | `FoO---###` | `FoO---9` |
| 5 | `fooo-#` | `fooo-1` |
| 6 | `fOO#####` | `fOO10` |

### Troubleshooting

To verify that your view returns the correct ID, use the following filter to get latest ID:

```
http://example.com/yourdb/_design/autoincrement/_view/short?descending=true&startkey=["FOO",{}]&endkey=["FOO"]
```

## 2. Setting Server Side Attributes

`.timestamp` and `.owner` attributes are set by the server automatically. Custom server side attribute definition will be supported soon.

# Roadmap

- [ ] Add document deduplication support
- [ ] Provide a way to resume interrupted downloads/uploads
- [ ] Stream videos directly from database

## 3. `get` recursively

`db.get your_document_id, {recurse: 'some.keypath'}` will fetch the
document with `your_document_id` and the documents with ids that match with
`recurse` keypath.

Checkout [the tests](./merge-deps.ls) for examples.
