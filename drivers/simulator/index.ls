require! '../driver-abstract': {DriverAbstract}

export class IoSimulatorDriver extends DriverAbstract
    ->
        super!
        @memory = {}

    read: (handle, callback) ->
        #console.log "IoSimulatorDriver: read from address: ", address, "amount: ", amount
        callback err=null, (@memory[handle.topic] or false)

    write: (handle, value, callback) ->
        @memory[handle.topic] = value
        console.log "IoSimulatorDriver: write to address: ", handle.topic, "value: ", value
        callback err=null
