require! \express
require! 'aktos-dcs/src/socketio-server': {SocketIOServer}

app = express!
http = require \http .Server app

# create socket.io server
io = (require "socket.io") http
new SocketIOServer io
# end of socket.io server creation

app.get "/", (req, res) ->
        console.log "req: ", req.path
        res.end """
            <html>
                <head>
                </head>
                <body>
                    <p>Hello World! </p>
                    <p> Time is: <b>#{new Date!}</b></p>
                </body>
            </head>
            """

port = 4001
http.listen port, ->
    console.log "listening on *:#{port}"

process.on 'SIGINT', ->
    console.log 'Received SIGINT, cleaning up...'
    process.exit 0
