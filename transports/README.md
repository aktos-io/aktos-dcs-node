# Description

A `Transport` is responsible to transport the telegram to another connector's
transport (or to a physical device) and may be one of the followings:

* TCP
* *UDP*
* Websocket
* Socket.io
* *WebRTC*
* Serial Port (RS-232, RS-485, etc...)
* *USB*
* *Can-Bus*
* Yet another `Actor`

# Transport Properties

* SHOULD reconnect on connection failures.
* MUST provide the following events:

  * `connect`
  * `disconnect`
  * `data`

* MUST provide the following methods:

  * `write data, callback`: callback will be fired when data is sent succesfully
    * `callback` will take 1 `error` argument. `error` is an Object which has a
      `resolved` method, which is called on error resolve.

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