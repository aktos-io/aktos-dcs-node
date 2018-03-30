create-hash = require 'sha.js'

export hash-passwd = (passwd) ->
    sha512 = create-hash \sha512
    sha512.update passwd, 'utf-8' .digest \hex


export class AuthError extends Error
    (@message) ->
        super ...
        Error.captureStackTrace(this, AuthError)
        @type = \AuthError
