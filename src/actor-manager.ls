require! './core': {ActorBase}
require! 'aea/debug-log': {debug-levels}
require! 'prelude-ls': {empty}

topic-match = (topic, keypath) ->
    # returns true if keypath matches with topic
    # else, return false


do test-topic-match = ->
    examples =
        * topic: "IoMessage.my-pin1", keypath: "IoMessage.*", expected: true
        * topic: "IoMessage.my-pin1", keypath: "SomeOther.my-pin1", expected: false
        * topic: "IoMessage.my-pin1", keypath: "*.my-pin1", expected: true
        * topic: "IoMessage.my-pin1", keypath: "*.my-pin2", expected: false
        * topic: "*.my-pin1", keypath: "SomeOther.my-pin1", expected: true
        * topic: "*.my-pin1", keypath: "SomeOther.my-pin2", expected: false
        * topic: "IoMessage.my-pin1", keypath: "*.*", expected: true
        * topic: "IoMessage.*", keypath: "IoMessage.*", expected: true
        * topic: "IoMessage.*", keypath: "IoMessage.my-pin1", expected: true
        * topic: "IoMessage.*", keypath: "IoMessage.my-pin1", expected: true

    for num, example of examples
        if (example.topic `topic-match` example.keypath) isnt example.expected
            throw "Test failed! (\##{num}) "

class _ActorManager extends ActorBase
    ->
        super \ActorManager
        @actor-list = [] # id, actor-object, subscriptions
        @subs-min-list = {}    # 'topic': [list of actors subscribed this topic]
        #@log.level = debug-levels.silent
        @subscription-list = {'*': []}
        @log.sections =[
            #\v
            #\vv
            #\vvv
            #\v3
            #\v4
            \dis-4
        ]

    register: (actor) ->
        if actor.actor-id not in [..id for @actor-list]
            @actor-list.push {id: actor.actor-id, actor: actor}
            @log.section \v, """\"#{actor.actor-id}\" #{"(#{actor.name})" if actor.name}has been registered. total: #{@actor-list.length}"""
        else
            @log.err "This actor has been registered before!", actor

        @update-subscriptions!

    update-subscriptions: ->
        # log section prefix: v3
        # update subscriptions
        for i in @actor-list
            if '*' in i.actor.subscriptions or empty i.actor.subscriptions
                s = @subscription-list['*']
                if i.actor.actor-id not in [..actor-id for s]
                    s.push i.actor
                continue
            else
                for topic in i.actor.subscriptions
                    unless @subscription-list[topic]
                        @subscription-list[topic] = []
                    s = @subscription-list[topic]
                    if i.actor.actor-id not in [..actor-id for s]
                        s.push i.actor

        @log.section \v3, "Subscriptions: ", @subscription-list

    subscribe-actor: (actor) ->
        # log section prefix: v4
        entry = [.. for @actor-list when ..id is actor.actor-id]
        entry.subscriptions = actor.subscriptions
        @update-subscriptions!

    inbox-put: (msg) ->
        @distribute-msg msg

    distribute-msg: (msg) ->
        # distribute subscribe-all messages
        # log.section prefix: "dis"
        i = 0
        @log.section \dis-4, "Subscriptions: ", @subscription-list
        @log.section \dis-vv, "------------ forwarding message ---------------"
        for topic, actors of @subscription-list
            @log.section \dis-v, "Distributing topic: #{topic}"
            for actor in actors when actor.actor-id isnt msg.sender
                @log.section \dis-vv, "------------ forwarding #{topic} message to actor ---------------"
                @log.section \dis-v, "forwarding msg: #{msg.msg_id} to #{actor.name}"
                @log.section \dis-vv, "actor: ", actor
                @log.section \dis-vv, "message: ", msg
                @log.section \dis-vv, "------------- end of forwarding to actor ---------------"

                actor.recv msg
                i++

        @log.section \vv, "------------ end of forwarding message, total forward: #{i}---------------"

# make a singleton
export class ActorManager
    instance = null
    ->
        instance ?:= new _ActorManager!
        return instance
