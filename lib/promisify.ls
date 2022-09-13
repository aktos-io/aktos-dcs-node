# promisify(f) for functions with single result
# promisify(true, f) to get array of results 

/* Note: 

In order to promisify a class method, do the following: 

    promisify myinstance.read.bind(myinstance)

*/
export function promisify many-args, f
    unless f?
        f = many-args
        many-args = false 

    if f.constructor.name is \AsyncFunction
        # already an async function, use it
        return f
 
    (...args) -> 
        new Promise (resolve, reject) ~>
            args.push (err, ...results) -> 
                if err
                    reject err 
                else
                    # resolve with all callback results if many-args is specified
                    resolve (if many-args then results else results[0])

            f.apply this, args


test = -> 
  sleep = (ms, f) -> setTimeout f, ms

  a = ->> 
    console.log "a started"
    await (promisify sleep) 2000ms
    console.log "a ended"

  do ->>
    console.log "test started"
    await (promisify promisify(a))!
    console.log "test ended"
# test!



/* Convert a callback style api into `await`able api within the source code 
 * with backwards compatibility. 
 * 
 * Add this line at the beginning of the function (or after parameter nomalization 
 * section, if exists): 

        callback <~ upgrade-promisify callback

 * Example: The following function: 

         myfunc = (some, param, callback) -> 
            ...do something
            callback err, res 

Should look like this: 

         myfunc = (some, param, callback) -> 
            
            callback <~ upgrade-promisify callback
            
            ...do something
            callback err, res 

*/
export upgrade-promisify = (callback, fn) -> 
    if callback?
        return fn callback

    return new Promise (_resolve, _reject) -> 
        promise-callback = (err, res) -> 
            if err then return _reject err 
            _resolve res

        fn promise-callback


# Converts a function that returns a Promise into a callback style function
export callbackify = (fn) ->
    (...args) ~>>
        callback = (args.splice -1, 1)[0] # extract last argument as callback
        try 
            res = await fn ...args 
            callback null, res 
        catch 
            callback e, null 
