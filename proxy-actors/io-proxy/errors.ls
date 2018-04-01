export class CodingError extends Error
    (@message) ->
        super ...
        Error.captureStackTrace(this, CodingError)
        @type = \CodingError
