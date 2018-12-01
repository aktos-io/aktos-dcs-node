require! '../driver-abstract': {DriverAbstract}
require! 'onoff': {Gpio}
require! '../../': {sleep}

/* Handle format:

handle =
    name: 'red'
    gpio: 0
    out: yes

*/

export class RpiGPIODriver extends DriverAbstract
    initialize: (handle, emit) ->
        if handle.out
            # this is an output
            console.log "#{handle.name} is initialized as output"
            @io[handle.name] = new Gpio handle.gpio, \out
        else
            console.log "#{handle.name} is initialized as input"
            @io[handle.name] = new Gpio handle.gpio, 'in', 'both'
                ..watch emit

    write: (handle, value, respond) ->
        # we got a write request to the target
        #console.log "we got ", value, "to write as ", handle
        @io[handle.name].write (if value => 1 else 0), respond

    read: (handle, respond) ->
        # we are requested to read the handle value from the target
        #console.log "do something to read the handle:", handle
        @io[handle.name].read respond

    start: ->
        @trigger \started

    stop: ->
        console.log "Stopping RpiGPIODriver..."
        for name, gpio of @io
            console.log "...unexporting #{name}"
            gpio.unexport!
        console.log "Stopped."
