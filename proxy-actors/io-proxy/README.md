# IoProxy*

Client and Handler take care of heartbeating, broadcasting, polling, lining-up etc.

# IoProxyClient

Usage:

```ls
require! 'dcs': {IoProxyClient}

io = new IoProxyClient do
    timeout: 1000ms
    route: '@some.route'
    fps: 12fps

# to write
io.write "some-value"

io.on \error, (err) ~>
    console.warn "We have an error: ", err

io.on \read, (value) ~>
    console.log "We got the value:", value
```

# IoProxyHandler

Important part for a proxy handler is the driver. Driver performs the whole work.

Usage:

```ls
require! 'dcs': {IoProxyHandler, DriverAbstract}

class TwitterDriver extends DriverAbstract
    write: (handle, value, respond) ->
        # we got a write request to the target
        console.log "we got ", value, "to write as ", handle
        respond err=null

    read: (handle, respond) ->
        # we are requested to read the handle value from the target
        console.log "do something to read the handle:", handle
        if handle.name is \ballot-totals
            console.log "getting ballot totals"
            err, tweets <~ client.get 'search/tweets.json', {q: '#' + hashtag}
            respond err, tweets?.statuses?.length
        else
            respond err=null, value={some-value: 1234}


# Handle may have any format that its driver is able to understand.
handle =
    name: 'ballot-totals'

driver = new TwitterDriver
io = new IoProxyHandler handle, "@twitter-service.ballot2", driver
```
