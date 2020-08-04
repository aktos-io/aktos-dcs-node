# Introduction 

1. `.read()`: Declare how read operations will be performed. Devices may allow 
    * Only sequential reading (block or single read)
    * Concurrent reading 
2. `.write()`: Declare how write operations will be performed. Devices may allow 
    * Only sequential writing (block or single write)
    * Concurrent writing
    * Concurrent writing with some restrictions 
3. Create and fire a polling loop in `init`, if necessary.
4. `.start()`: [REQUIRED] Declare the starting procedure of the driver, when and how 
    it becomes `.connected = yes`. All `IoHandler`s will try to `.start()` the 
    device if it's not `.started`. 
5. `.init-handle(handle, broadcast)`: Register the handle pointers within some variable 
    for later use. Broadcast some value if it's necessary by `broadcast` function.

TODO: `._exec_sequential(func, ...args, callback)` will use the provided method but will 
execute invocations sequentially.

### States 

.starting 
.started 

    
# Types of drivers:

According to concurrency:

    1. Concurrent read/write

        A device might be able to handle its io concurrently, such as:
        * Raspberry GPIO
        * A database/webservice
        * More than one device in the backend

    2. Sequential read/write

        A device might not let concurrent read/writes (most of the devices) that
        can only handle one telegram at a time, such as
        * Most of the PLC's (especially which uses RS485 or like)

