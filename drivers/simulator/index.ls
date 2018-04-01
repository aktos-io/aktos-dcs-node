export class IoSimulatorDriver
    ->
        @memory = {}

    read: (address, amount, callback) ->
        #console.log "IoSimulatorDriver: read from address: ", address, "amount: ", amount
        callback err=null, (@memory[address] or false)

    write: (address, value, callback) ->
        @memory[address] = value
        console.log "IoSimulatorDriver: write to address: ", address, "value: ", value
        callback err=null
