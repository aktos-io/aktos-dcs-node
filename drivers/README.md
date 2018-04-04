# API of a Driver

## Methods
---------------
* err, value <~ **read** handle
* err <~ **write** handle, value
* **start**!
* **stop**!
* **watch-changes** handle, callback(err, value)

## Events
---------------
* on 'connect': fired once on a successful read
* on 'disconnect': fired once when a read is failed

## Parameters
---------------
### Handle

`handle` is an object where its driver understands its properties.
However, there are some common properties:

* watch: yes/no: whether watch this variable to generate events on changes or not.
* out: yes/no: this variable is intended to be an output.
* address: address of the variable (if there is any)
* threshold: percent of the actual value that is used for deciding a change. default: 0.001
