export class IoSimulatorProtocol
    ->
        @memory = {}

    read: (address, amount, callback) ->
        #console.log "IoSimulatorProtocol: read from address: ", address, "amount: ", amount
        callback err=null, (@memory[address] or false)

    write: (address, value, callback) ->
        @memory[address] = value
        console.log "IoSimulatorProtocol: write to address: ", address, "value: ", value
        callback err=null
