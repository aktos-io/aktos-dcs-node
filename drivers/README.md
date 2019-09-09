# API of a Driver

## Methods
---------------
* **read** handle, respond(err, value)
* **write** handle, value, respond(err)
* **start**!
* **stop**!
* **initialize** handle, broadcast(err, value)

## Events
---------------
* on 'connect': fired on the successful first read
* on 'disconnect': fired on the first failed read

## Parameters
---------------
### Handle

`handle` is an object where its driver understands its properties.
Suggested property names:

* watch: yes/no: whether watch this variable to generate events on changes or not.
* out: yes/no: this variable is intended to be an output.
* address: address of the variable (if there is any)
* threshold: percent of the actual value that is used for deciding a change. default: 0.001
