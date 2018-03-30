# aktos-dcs-node

### Description

Node.js port of [`aktos-dcs`](https://github.com/aktos-io/aktos-dcs) library (v2).

# Install

1. `git init app && cd app`
2. `git submodule add https://github.com/aktos-io/aktos-dcs-node dcs`
3. `./dcs/update.sh --all`

### Testing

1. Create `app/hello-world.ls`:

  ```ls
  require! './dcs': {Actor, sleep}

  # create a Hello process
  new class Hello extends Actor
      action: ->
          <~ :lo(op) ~>
              @log.log "hello!"
              <~ sleep 1000ms
              lo(op)

  # create a World process
  new class World extends Actor
      action: ->
          <~ :lo(op) ~>
              @log.log "world!"
              <~ sleep 2000ms
              lo(op)
  ```

2. Run:

  ```log
  $ lsc ./app/hello-world.ls
  [01:16:56.880] 257f4bea-8f2f-4 : hello!
  [01:16:56.884] 45e37675-6ec5-4 : world!
  [01:16:57.886] 257f4bea-8f2f-4 : hello!
  [01:16:58.885] 45e37675-6ec5-4 : world!
  [01:16:58.887] 257f4bea-8f2f-4 : hello!
  [01:16:59.888] 257f4bea-8f2f-4 : hello!
  ```    

If you see the above output, then everything should be okay.

3. For more examples, See [**dcs-nodejs-examples**](https://github.com/aktos-io/dcs-nodejs-examples).


# Additional Features

`aktos-dcs-node` provides following transport and connectors:

### [Transports](./transports/README.md)

* Serial Port Transport

### [Connectors](./connectors/README.md)

* CouchDB
* SocketIO (Server + Client)
* TCP (Server + Client)
* Omron
  * Hostlink
  * FINS
* Siemens
  * S7 Comm
* Raspberry
  * Digital Input
  * Digital Output

# Contact

info@aktos.io
