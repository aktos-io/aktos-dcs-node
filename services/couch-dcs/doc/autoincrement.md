# Incremental ID's

## In Practice

Put the following view into your database as `_design/autoincrement`: 

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

Use `someprefix-####` as the `_id` for your document upon saving. `CouchDcsServer`'s' `.put` handler will handle the rest. 


### Behavior

1. *On save*: Your prefix is calculated by splitting right before first '#'
character and grabbing left side of the result.

| Autoincrement ID | Calculated Prefix | Example ID |
| ---- | ----- | ---- |
| `foo####` | `foo` | `foo1234` |
| `foo-####` | `foo-` | `foo-1234` |
| `Foo-####` | `Foo-` | `Foo-1234` |

2. *On calculating next ID*: Current biggest ID is calculated by splitting right before any alphanumeric characters, grabbing left side, converting to upper case.

For example, we have `foo-5` in the database. Following autoincremented IDs will be assigned for the IDs:

| Seq. | Provided `doc._id` | Saved as |
| ---- | ----- | ----- |
| 1 | `foo-####` | `foo-6` |
| 2 | `foo-####` | `foo-7` |
| 3 | `foo####`  | `foo8`
| 4 | `FoO---####` | `FoO---9` |
| 5 | `fooo-####` | `fooo-1` |
| 6 | `fOO#####` | `fOO10` |

### Troubleshooting

To verify that your view returns the correct ID, use the following filter to get latest ID:

```
http://example.com/yourdb/_design/autoincrement/_view/short?descending=true&startkey=["FOO",{}]&endkey=["FOO"]
```

### Theory:

1. Design your document ids something like: `mydoc/1` or `mydoc-1`
2. Create a view that returns the numeric part of the document 
3. Before creating a new document, get the greatest document id with the view.
4. Increment the id by 1
5. Try to put the document. 
6. If you get `401`, go to step 3.
