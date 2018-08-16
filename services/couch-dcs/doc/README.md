# Description

Here is some quick notes about CouchDB usage.

# Difference between List and Show functions

* "Show functions" are to transform simple documents.
* "List functions" are to transform "view"s.

# Recipes

### Create A New Database

1. Create a random user
2. Create the `_security` doc and make that user db admin (**see** ./security)
3. Restore the `_design` docs.

### Testing the installation

Following request MUST FAIL:

     curl http://localhost:5984/yourdb/
     {"error":"unauthorized","reason":"Authentication required."}

**If above request DOES NOT FAIL,** then it means `yourdb` is **public** so anyone can read your DB. You MUST consider putting your CouchDB behind a proxy server.

### Dump and Restore

https://github.com/raffi-minassian/couchdb-dump

# Useful Links
- http://www.paperplanes.de/2010/7/26/10_annoying_things_about_couchdb.html
- https://developer.ibm.com/clouddataservices/2016/03/22/simple-couchdb-and-cloudant-backup/
