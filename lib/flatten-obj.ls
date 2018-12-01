# Taken from: https://gist.github.com/penguinboy/762197#gistcomment-921942
``
let isPlainObj = (o) => Boolean(
  o && o.constructor && o.constructor.prototype && o.constructor.prototype.hasOwnProperty("isPrototypeOf")
)

let flattenObj = (obj, keys=[]) => {
  return Object.keys(obj).reduce((acc, key) => {
    return Object.assign(acc, isPlainObj(obj[key])
      ? flattenObj(obj[key], keys.concat(key))
      : {[keys.concat(key).join(".")]: obj[key]}
    )
  }, {})
}
``

export flattenObj
