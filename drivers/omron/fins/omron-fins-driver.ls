require! 'dcs': {EventEmitter, Logger, Signal, sleep, pack}
require! 'omron-fins': fins
require! 'prelude-ls': {chars, empty, reverse, unique}
require! 'colors': {bg-yellow}
require! 'dcs/lib/memory-map': {bit-write, bit-test}
require! '../../driver-abstract': {DriverAbstract}
require! '../../../lib/promisify': {promisify}


/* ***********************************************

Memory area constants: https://github.com/ptrks/node-omron-fins/blob/master/lib/constants.js

commands:
    * read
    * write

address:
    either "WORD_ADDR" or "WORD_ADDR.BIT_NUM" format

value:
    if command is 'write' =>
        value to write to
        * single (write to the address)
        * array (write starting from the address)
    if command is 'read'  =>
        if bitwise => ignored
        if word => number of addresses to read

*****************************************************/

export class OmronFinsDriver extends DriverAbstract
    (@opts={}) ->
        super!
        @log = new Logger \OmronFinsDriver
        @target = {port: 9600, host: '192.168.250.1'} <<< @opts
        @timeout = 2000ms  # 100ms

        @log.log bg-yellow "Using #{@target.host}:#{@target.port}"
        @client = fins.FinsClient @target.port, @target.host

        @q = {} # exec queue. Key field is the sequence number (FinsClient.SID).

        @client.on \reply, (msg) ~>
            if msg.sid of @q
                # got an expected reply
                @q[msg.sid].go err=null, res=msg 
                delete @q[msg.sid]
            else 
                @log.error "Unexpected response: (none in #{Object.keys @q}):", msg

        @client.on \error, (err) ~> 
            @log.error "FINS Client error:", err 

        @client.on \timeout, (err) ~> 
            @log.error "FINS timeout:", err

        # PLC connection status 
        @connected = no 
        @on \connected, ~> 
            @log.info "Connected to PLC"
        @on \disconnected, ~> 
            @log.info "Disconnected from PLC"

        @check-heartbeating!


    check-heartbeating: ->>
        @log.log "Starting the heartbeat check with the PLC"
        while true
            try await @exec \read, "C0:0", 1
            await sleep 10_000ms
   
    exec: (command, ...args) ->> 
        # This is the key function that transforms the discrete .read/.write functions 
        # into async functions        
        SID = @client[command] ...args
        @q[SID] = new Signal!
        return new Promise (resolve, reject) ~>
            @q[SID].wait @timeout, (err, res) ~> 
                if err 
                    reject(err)
                    @trigger \disconnected if @connected
                    @connected = no 
                    sleep 0 ~> 
                        delete @q[SID] if SID of @q
                else 
                    resolve(res)
                    @trigger \connected unless @connected
                    @connected = yes


# Example
# ----------------------------------------------------------------------
if require.main is module
    require! 'dcs': {Actor}
    class OmronFinsActor extends Actor 
        (opts) -> 
            super opts.name 
            driver = new OmronFinsDriver (opts)
            @on-topic "#{@name}.read", (msg) ~>>
                try 
                    res = await driver.exec 'read', msg.data.0, msg.data.1
                    @send-response msg, {err: null, res}
                catch 
                    @send-response msg, {err: e} 

            @on-topic "#{@name}.write", (msg) ~>>
                try 
                    res = await driver.exec 'write', msg.data.0, msg.data.1
                    @send-response msg, {err: null, res}
                catch 
                    @send-response msg, {err: e} 


    new OmronFinsActor {name: \my1, host: '192.168.250.9'}

    new class TestReader extends Actor
        action: ->> 
            addr = 0
            while true 
                addr-str = "D#{addr}"
                @log.log "Reading #{addr-str }..."
                try 
                    msg = await @send-request {topic: "my1.read", timeout: 2500ms}
                        , ["#{addr-str }", 1]

                    if msg.data.err 
                        throw new Error that 

                    @log.log "Value of addr: #{addr-str } is:", msg.data.res.values
                catch 
                    @log.error "Error in read response:", e 

                await sleep 3000ms 
                addr++

    new class TestWriter extends Actor
        action: ->> 
            addr = 0
            value = 123
            while true 
                addr-str = "D#{addr}"
                @log.log "Writing to #{addr-str } value: #{value}..."
                try 
                    msg = await @send-request {topic: "my1.write", timeout: 2500ms}
                        , ["#{addr-str }", value++]

                    if msg.data.err 
                        throw new Error that 
                catch 
                    @log.error "Error in write response:", e 

                await sleep 3500ms 
                addr++
                if addr > 100 => addr = 0 