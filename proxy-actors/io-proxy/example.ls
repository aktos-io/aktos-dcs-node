io-table =
    io:
        simulator:
            motor1:
                address: 'C100.01'
            motor2:
                address: 'C100.02'
            conveyor1:
                address: 'C100.03'

require! 'dcs/proxy-actors/io-proxy': {IoProxyHandler, MemoryMap}
require! 'dcs/protocols/simulator': {IoSimulatorProtocol}

simulator-protocol = new IoSimulatorProtocol!
simulator = new MemoryMap do
    table: io-table
    namespace: \io.simulator

for let handle in simulator.get-handles!
    new IoProxyHandler handle, simulator-protocol
