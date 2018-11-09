# Get superclass methods
# See https://github.com/gkz/LiveScript/issues/1075

export get-super = (ctx, method) ->
    # Based on https://stackoverflow.com/a/44462982/1952991
    Object.getPrototypeOf(Object.getPrototypeOf ctx)[method].bind(ctx)

/*
# Usage:
class Y extends X
  load: ->
    (get-super this, 'load') ...
    # do extra work here
*/

export _super =
  _super: (method) ->
    Object.getPrototypeOf(Object.getPrototypeOf this)[method].bind(this)

/*
class Y extends X implements _super
  load: (data) ->
    (@_super \load) ...
    # do your extra work here
*/
