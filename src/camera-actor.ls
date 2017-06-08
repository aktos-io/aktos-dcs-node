"""
mjpeg-camera = require \mjpeg-camera
camera = new mjpeg-camera do
    name: 'backdoor'
    url: 'http://localhost:8080/?action=stream'

camera.on \data, (frame) ->
    io.emit \frame, frame.data.to-string \base64

try
    camera.start!
catch
    console.log "mjpeg-camera can not be started..."
"""
