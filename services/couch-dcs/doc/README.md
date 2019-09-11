# Description

Here is some quick notes about CouchDB usage.

# Difference between List and Show functions

* "Show functions" are to transform simple documents.
* "List functions" are to transform "view"s.

# Recipes

### Create A New Database For A New Customer

1. Create a new db admin user: [./security.md#create-db-users](./security.md#create-db-users)
2. Create a new database. 
3. Create the `_security` doc and make that user db admin in that database: [./security.md#security-per-database](./security.md#security-per-database)
4. Restore (or populate) the `_design` docs according to your needs.

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
