"""

Usage:

    1. Run this file in a terminal:

        ./run-example socketio-server-test.ls

    2. Open `./socketio-webapp/index.html` file via a browser (eg. Chromium)

    3. Open same `./socketio-webapp/index.html` file on another window

    4. Move sliders at top (at `aktos-dcs Test Zone` segment)

    5. See that values are synchronized between webapps and console output.

"""
require! \express
require! 'dcs': {SocketIOServer, Broker, Actor}
require! 'aea': {sleep}

# -----------------------------------------------------------------------------
#               Start of standard web server settings
# -----------------------------------------------------------------------------

app = express!
http = require \http .Server app

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

# -----------------------------------------------------------------------------
#               End of standard web server settings
# -----------------------------------------------------------------------------

# create socket.io server
io = (require "socket.io") http
new SocketIOServer io
# end of socket.io server creation

# Optional
# start a broker to share messages over dcs network
new Broker!

# -----------------------------------------------------------------------------
# Test codes
# -----------------------------------------------------------------------------
class Monitor extends Actor
    ->
        super \Monitor
        @subscribe "IoMessage.my-test-pin3"

        @on-receive (msg) ~>
            @log.log "Monitor got msg: ", msg.payload, msg.topic

    action: ->
        @log.log "#{@name} started..."

class Simulator extends Actor
    ->
        super 'simulator'

        @on-receive (msg) ~>
            @log.log "Simulator got message: ", msg.payload
            #@echo msg

    action: ->
        @log.log "Simulator started..."

    echo: (msg) ->
        @log.log "Got message: Payload: ", msg.payload
        msg.payload++
        @log.log "...payload incremented by 1: ", msg.payload
        @log.log "Echoing message back in 1000ms..."
        <~ sleep 1000ms
        @send-enveloped msg


#new Simulator!
new Monitor!
