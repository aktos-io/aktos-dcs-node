# aktos-dcs-node

### Description 

Node.js port of [`aktos-dcs`](https://github.com/aktos-io/aktos-dcs) library (v2).

### Install 

1. `git init yourproject && cd yourproject`
2. `git submodule add https://github.com/aktos-io/aktos-dcs-node dcs`
3. `./dcs/update.sh --all`

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
  
# Examples 

Examples can be found [here](https://github.com/aktos-io/dcs-nodejs-examples)

# Contact 

info@aktos.io
