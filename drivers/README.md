# API of a Driver

### Methods

* err, value <~ **read** handle
* err <~ write handle, value
* start!
* stop!
* watch-changes handle, callback(err, value)


### Handle

`handle` is an object where its driver understands its properties.
