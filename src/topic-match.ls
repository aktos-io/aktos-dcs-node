require! 'prelude-ls': {max}

export topic-match = (topic, keypath, opts={}) ->
    # returns true if keypath fits into topic
    # else, return false
    if '**' in [topic, keypath]
        console.log "topic is **, immediately matches with anything" if opts.debug
        return yes

    topic-arr = topic.split '.'
    keypath-arr = keypath.split '.'

    for index in [til max(topic-arr.length, keypath-arr.length)]
        topic-part = try topic-arr[index]
        keypath-part = try keypath-arr[index]

        console.log "topic-part: #{topic-part}, keypath-part: #{keypath-part}" if opts.debug

        if '*' in [keypath-part, topic-part]
            if undefined in [keypath-part, topic-part]
                console.log "returning false because there is no command to look for match" if opts.debug
                return false
            continue

        if undefined in [keypath-part, topic-part]
            console.log "returning false because there is no command to look for match" if opts.debug
            return false

        if '**' in [keypath-part, topic-part]
            console.log "returning true because '**' will match with anything." if opts.debug
            return true

        if topic-part isnt keypath-part
            #console.log "topic-part: #{topic-part}, keypath-part: #{keypath-part}"
            return false

    console.log "no condition broke the match." if opts.debug
    return true


do test-topic-match = ->

    # format:
    # message.command.command.command....

    examples =
        # simple matches
        * topic: "foo.bar", keypath: "foo.*", expected: true
        * topic: "*.bar", keypath: "foo.*", expected: true
        * topic: "foo.bar", keypath: "baz.bar", expected: false

        # any foo messages that contains exactly two level deep commands
        * topic: "foo.bar", keypath: "foo.*.*", expected: false

        # publish exactly 3 level deep topics, subscribe to foo messages
        # that are only one level deep.
        * topic: "foo.*.bar", keypath: "foo.*", expected: false

        # first: any foo messages that contains two or more commands
        * topic: "foo.*.**", keypath: "foo.bar.baz", expected: true
        * topic: "foo.*.**", keypath: "foo.bar", expected: false
        * topic: "foo.*.**", keypath: "foo.bar.baz.qux", expected: true

        * topic: "foo.**", keypath: "foo.bar.baz.qux", expected: true
        * topic: "foo.**", keypath: "*.bar.baz.qux", expected: true

        * topic: "foo.bar", keypath: "*.*", expected: true
        * topic: "foo.bar", keypath: "*", expected: false
        * topic: "*", keypath: "foo.bar", expected: false
        * topic: "foo.bar", keypath: "**", expected: true

        * topic: "*", keypath: "*", expected: true
        * topic: "**", keypath: "*", expected: true
        * topic: "*", keypath: "**", expected: true
        * topic: "**", keypath: "**", expected: true
        * topic: "*.*", keypath: "**", expected: true
        * topic: "**", keypath: "*.*", expected: true

    for num of examples
        example = examples[num]
        result = example.topic `topic-match` example.keypath
        if result isnt example.expected
            console.log "Test failed in \##{num}, re-running in debug mode: "
            console.log "comparing if '#{example.topic}' matches with '#{example.keypath}' expecting: #{example.expected}"
            console.log "---------------------------------------------------"
            topic-match example.topic, example.keypath, {+debug}
            console.log "---------------------------------------------------"
            process.exit 1
