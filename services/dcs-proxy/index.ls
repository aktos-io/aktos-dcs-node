# NodeJS components
require! './socket-io/server': {DcsSocketIOServer}
require! './tcp/server': {DcsTcpServer}
require! '../../src/auth-db': {AuthDB, as-docs}

module.exports = {
    DcsSocketIOServer
    DcsTcpServer
    AuthDB, as-docs
}
