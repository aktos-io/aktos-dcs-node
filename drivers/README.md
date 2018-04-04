# API of a Driver

### Methods

* err, value <~ **read** handle
* err <~ write handle, value
* start!
* stop!
* watch-changes handle, callback(err, value)


### Handle

`handle` is an object where its driver understands its properties.
However, there are some common properties:

* watch: yes/no: whether watch this variable to generate events on changes or not.
* out: yes/no: this variable is intended to be an output.

...and some recommended attributes:

* address: address of the variable (if there is any)
* treshold: percent of the actual value that is used for deciding a change. default: 0.001
