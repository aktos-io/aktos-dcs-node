export sleep = (ms, fn) -> 
    if fn?
        return set-timeout fn, ms
    else
        return new Promise (resolve) -> 
            set-timeout resolve, ms 

export after = sleep
export clear-timer = (x) -> clear-interval x
require("setimmediate")