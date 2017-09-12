require! 'aea': {sleep}
require! 'dcs': {Actor}
require! 'colors': {bg-green, bg-red}
require! 'onoff': {Gpio}

class Io extends Actor
    (@opts) ->
        unless @opts.pin? and @opts.name?
            throw 'pin name and number is required'

        super @opts.name
        namespace = if @opts.namespace
            "#{that}"
        else
            'io'

        @topic = "#{namespace}.#{@opts.name}"
        @log.log "Initializing pin number #{@opts.pin} with on topic: #{@topic}"
        @subscribe @topic

        @prev = null

export class DInput extends Io
    ->
        super ...
        input = new Gpio @opts.pin, 'in', 'both'

        send-value = (value) ~>
            if value isnt @prev
                @log.log "sending prev: #{@prev} -> curr: #{value}"
                @send {curr: value, prev: @prev}, @topic
                @prev = value
            else
                @log.log "Not changed, not sending. curr: #{value}"

        input.read (err, value) ->
            send-value value

        input.watch (err, value) ~>
            if err
                @log.log "Error reading pin."
                @kill 'READERR'
                return
            send-value value

        @on \update, ~>
            @log.log "requested update, sending current status..."
            input.read (err, value) ~>
                @send {curr: @prev}, @topic

        @on \kill, ~>
            <~ input.unexport
            @log.log "pin destroyed."


export class DOutput extends Io
    ->
        super ...
        output = new Gpio @opts.pin, \out

        send-value = (value, reply-to) ~>
            @log.log "sending prev: #{@prev} -> curr: #{value}"
            @send {curr: value, prev: @prev}, @topic
            @send-response reply-to, {curr: value, prev: @prev} if reply-to
            @prev = value

        write = (value, reply-to) ~>
            value = if value => 1 else 0
            @log.log "writing: #{value}"
            output.write value, (err) ~>
                if err
                    @log.err "error while writing! (did you check permissions?)"
                    @kill 'READERR'
                    @send {error: reason: 'can not write to output'}, @topic
                    return
                send-value value, reply-to


        write (@opts.initial or 0)

        @on \data, (msg) ~>
            write msg.payload.val, msg if msg.payload.val?

        @on \update, ~>
            @log.log "requested update, sending current status..."
            send-value @prev

        @on \kill, ~>
            <~ output.unexport
            @log.log "pin destroyed."
