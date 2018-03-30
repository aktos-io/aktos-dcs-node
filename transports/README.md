# Description

A `Transport` is responsible to transport the string or array buffer telegram via
a physical medium.

# Transport Properties

### Behaviour

* SHOULD reconnect on connection failures.

### MUST provide the following events:

* `connect`: Fired on first connect (initialization), reconnect
    (valid for client side transports, no need for server side handlers.)
* `disconnect`
* `data`

### MUST provide the following methods:

* `write data, callback(error)`: callback will be fired when data is sent succesfully
* `error`: `null` for success, truthy value for error.

* `is-connected!`: returns true or false according to current transport connection
status.

* `connect!`: method for initializing the medium (connect, dial, etc.)

# Tests

1. DO: Unplug the physical connection, start the application.
   EXPECT: Transport should start trying to reconnect.

2. After `test#1` is OK,
   DO: Plug the physical connection.
   EXPECT: Transport should
     1. connect immediately
     2. fire 'connect' event

3. After `test#2` is OK,
   DO: Unplug the physical connection.
   EXPECT: Transport should
     1. start trying to reconnect
     2. fire 'disconnect' event

# Status

Currently the following transports are and/or planned to be implemented:

- [x] TCP: A TCP transport layer which handles re-connection
- [ ] DCS-UDP: A DCS transport over UDP which will handle heartbeat, app level ACK, etc.
- [ ] Websocket
- [x] Socket.io
- [x] Serial Port (RS-232, RS-485, etc...)
- [ ] USB
- [ ] CanBus (hardware specific)
- [ ] E-mail
- [ ] SMS
- [ ] WebRTC
- [ ] EtherCAT
