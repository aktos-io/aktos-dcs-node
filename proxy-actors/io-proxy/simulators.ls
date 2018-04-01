require! 'dcs/lib/memory-map': {MemoryMap}
require! './io-proxy-handler': {IoProxyHandler}
require! './simulator-protocol': {IoSimulatorProtocol}

mmap = new MemoryMap do
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

        new IoProxyHandler \io.plc1.motor1, simulator-protocol
        new IoProxyHandler \io.plc1.motor2, simulator-protocol
        new IoProxyHandler \io.plc1.conveyor1, simulator-protocol
