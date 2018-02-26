jsondiffpatch = require 'jsondiffpatch'
require! \expect

export make-tests = (lib-name, tests) ->
    if typeof! lib-name is \Object
        tests = lib-name
        lib-name = \Tests

    #consolelog "++++++++++ Start of tests: #{lib-name}"
    for name, test of tests
        @expect = expect
        try
            res = test.call this
        catch
            #consoleerror   "- FAILED on test: #{name}"
            if (typeof! e.matcherResult isnt \Object) or not e.matcherResult.actual
                throw e

            actual = JSON.stringify(e.matcherResult.actual)
            expected = JSON.stringify(e.matcherResult.expected)
            #consolelog     "- result  \t: ", actual
            #consolelog     "- expected\t: ", expected

            d = jsondiffpatch.diff e.matcherResult.actual, e.matcherResult.expected
            #consoleerror "diff: "
            #consoleerror (JSON.stringify d, null, 2)

            # Visual diff
            left = encodeURIComponent expected
            right = encodeURIComponent actual
            #consolelog "Visual Diff: http://benjamine.github.io/jsondiffpatch/demo/index.html?desc=Expected..Actual&left=#{left}&right=#{right}"

            throw  "- FAILED on test: #{name}"


        if typeof! res is \Undefined
            #consolelog "...passed from external test: #{name}."
            null
        else if not res
            #consolewarn "Test [#{name}] is skipped..."
            null
        else
            expected = JSON.stringify(res.expect)
            result = JSON.stringify(res.result)
            if jsondiffpatch.diff res.result, res.expect
                #consoleerror   "- FAILED on test: #{name}"
                #consolelog     "- diff    \t: ", that
                #consolelog     "- result  \t: ", result
                #consolelog     "- expected\t: ", expected
                #consolewarn "DEPRECATED: ----------- convert to 'expect' method --------------"
                throw   "- FAILED on test: #{name}"

            else
                #consolelog "...passed from test: #{name}."
    #consolelog "End of tests."
