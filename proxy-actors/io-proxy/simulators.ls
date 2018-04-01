require! 'dcs/lib/memory-map': {MemoryMap}
require! './io-proxy-handler': {IoProxyHandler}
require! './simulator-protocol': {IoSimulatorProtocol}

io-table =
    io:
        plc1:
            motor1:
                address: 'C100.01'
            motor2:
                address: 'C100.02'
            conveyor1:
                address: 'C100.03'

export class PhysicalTargetSimulator
    ->
        simulator-protocol = new IoSimulatorProtocol!
        plc1 = new MemoryMap do
            table: io-table
            namespace: \io.plc1

        for let handle in plc1.get-handles!
            new IoProxyHandler handle, simulator-protocol
