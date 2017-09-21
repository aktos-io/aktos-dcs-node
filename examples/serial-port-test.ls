require! '../transports/serial-port': {SerialPortTransport}
require! '..': {Logger, sleep}

logger = new Logger 'APP'
port = new SerialPortTransport {
    baudrate: 9600baud
    port: '/dev/ttyUSB0'
    }
    ..on \connect, ->
        logger.log "app says serial port is connected"

    ..on \data, (frame) ~>
        logger.log "frame received:", frame

    ..on \disconnect, ~>
        logger.log "app says disconnected "

<~ :lo(op) ~>
    logger.log "sending something..."
    err <~ port.write ('something' * 40) + '\n'
    if err
        logger.err "something went wrong while writing, waiting for resolution..."
        <~ err.resolved
        logger.log "error is resolved, continuing"
        lo(op)
    else
        <~ sleep 2000ms
        lo(op)
