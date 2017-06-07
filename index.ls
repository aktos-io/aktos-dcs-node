require! './src/actor': {Actor}
require! './src/io-actor': {IoActor}
require! './src/proxy-actor': {ProxyActor}

console.warn "proxy actor is: ", ProxyActor

module.exports = ProxyActor
