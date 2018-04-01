export class IoSimulatorProtocol
    ->
        @memory = {}

    read: (address, amount, callback) ->
        console.log "IO simulator protocol reading from address: ", address, "amount: ", amount
        callback err=null, (@memory[address] or false)

    write: (address, value, callback) ->
        @memory[address] = value
        console.log "protocol writing to address: ", address, "value: ", value
        callback err=null
