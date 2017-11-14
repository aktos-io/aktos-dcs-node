jsondiffpatch = require 'jsondiffpatch'

export make-tests = (lib-name, tests) ->
    if typeof! lib-name is \Object
        tests = lib-name
        lib-name = \Tests

    console.log "++++++++++ Start of tests: #{lib-name}"
    for let name, test of tests
        res = test.call this
        unless res
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
