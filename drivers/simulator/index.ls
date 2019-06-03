require! '../driver-abstract': {DriverAbstract}

export class IoSimulatorDriver extends DriverAbstract
    ->
        super!
        @memory = {}

    init-handle: (handle, emit) -> 

    read: (handle, callback) ->
        #console.log "IoSimulatorDriver: read from address: ", address, "amount: ", amount
        callback err=null, (@memory[handle.route] or false)

    write: (handle, value, callback) ->
        @memory[handle.route] = value
        console.log "IoSimulatorDriver: write to address: ", handle.route, "value: ", value
        callback err=null
