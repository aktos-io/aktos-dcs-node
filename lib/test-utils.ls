jsondiffpatch = require 'jsondiffpatch'
require! \expect

export make-tests = (lib-name, tests) ->
    if typeof! lib-name is \Object
        tests = lib-name
        lib-name = \Tests

    console.log "++++++++++ Start of tests: #{lib-name}"
    for name, test of tests
        @expect = expect
        try
            res = test.call this
        catch
            console.error   "- FAILED on test: #{name}"
            console.log     "- result  \t: ", JSON.stringify(e.matcherResult.actual)
            console.log     "- expected\t: ", JSON.stringify(e.matcherResult.expected)

            d = jsondiffpatch.diff e.matcherResult.actual, e.matcherResult.expected
            console.error "diff: "
            console.error (JSON.stringify d, null, 2)
            throw  "- FAILED on test: #{name}"


        if typeof! res is \Undefined
            console.log "...passed from external test: #{name}."

        else if not res
            console.warn "Test [#{name}] is skipped..."
        else
            try
                expected = JSON.stringify(res.expect)
                result = JSON.stringify(res.result)
                if jsondiffpatch.diff res.result, res.expect
                    console.error   "- FAILED on test: #{name}"
                    console.log     "- diff    \t: ", that
                    console.log     "- result  \t: ", result
                    console.log     "- expected\t: ", expected
                else
                    console.log "...passed from test: #{name}."
            catch
                debugger
    console.log "End of tests."
