require! './actor': {Actor}

export class BrowserStorage extends Actor
    (@prefix) ->
        super "BrowserStorage-#{@prefix}"

    action: ->
        @s = local-storage

    set: (key, value) ->
        try
            @s.set-item "#{@name}-#{key}", JSON.stringify value
        catch
            debugger
            err =
                title: "Browser Storage: Set"
                message:
                    "Error while saving key: ", key, "error is: ", e

            @log.err err.message
            @send 'app.log.err', err

    del: (key) ->
        @s.remove-item "#{@name}-#{key}"

    get: (key) ->
        try
            JSON.parse @s.get-item "#{@name}-#{key}"
        catch
            debugger
            err =
                title: "Browser Storage: Get"
                message:
                    "Error while getting key: ", key, "err is: ", e

            @log.err err.message
            @send 'app.log.err', err
