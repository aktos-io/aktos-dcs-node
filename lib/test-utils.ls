'''
Example test:

make-tests 'foo-lib', tests =
    'hello world': ->
        orig = {hello: 'world'}
        _new = {hi: 'there'}

        expect foo orig, _new
        .to-equal {thats: 'nice'}

    'upps': ->
        docs = <[ some things here ]>

        expect (-> foo docs)
        .to-throw "Huston, we have a problem!"

    'skipped test': ->
        return false # Skipped tests will drop a warning into the console.

        # doing some serious tests here
        ...


# You can split tests into files and run them by referencing an object:
require! './some'
require! './thing'
require! './important'
make-tests 'my-lib', {some, thing, important}

'''

jsondiffpatch = require 'jsondiffpatch'
require! \expect
require! './packing': {clone}
require! './flatten-obj': {flattenObj}

run-test = (name, test) ->
    @expect = expect
    @clone = clone

    try
        res = test.call this
    catch
        e.test-name = name
        if (typeof! e.matcherResult isnt \Object) or not e.matcherResult.actual
            # Errors related to test setup (exception inside test function)
            console.error "Something went wrong while running #{name}:", e 
            throw e

        console.error "FAILED test: #{name}", e

        actual = JSON.stringify(e.matcherResult.actual)
        expected = JSON.stringify(e.matcherResult.expected)
        console.log     "- expected\t: ", expected
        console.log     "- result  \t: ", actual
        console.error " - diff \t: "
        d = jsondiffpatch.diff e.matcherResult.expected, e.matcherResult.actual
        console.error (JSON.stringify d, null, 2)

        # Visual diff
        left = encodeURIComponent expected
        right = encodeURIComponent actual
        console.log "Visual Diff: http://benjamine.github.io/jsondiffpatch/demo/index.html?desc=Expected..Actual&left=#{left}&right=#{right}"

        # Re-throw the exception
        throw  e



    if typeof! res is \Undefined
        #console.log "...passed from external test: #{name}."
        null
    else if not res
        console.warn "Test [#{name}] is skipped..."
        null
    else
        expected = JSON.stringify(res.expect)
        result = JSON.stringify(res.result)
        if jsondiffpatch.diff res.result, res.expect
            console.error   "- FAILED on test: #{name}"
            console.log     "- diff    \t: ", that
            console.log     "- result  \t: ", result
            console.log     "- expected\t: ", expected
            console.warn "DEPRECATED: ----------- convert to 'expect' method --------------"
            throw   "- FAILED on test: #{name}"
        else
            #console.log "...passed from test: #{name}."


export make-tests = (lib-name, tests) ->
    if typeof! lib-name is \Object
        tests = lib-name
        lib-name = \Tests

    console.log "+++ Start of #{lib-name}"
    unless typeof! tests is \Object
        tests = {test: tests}
    for name, test of flattenObj tests
        console.log "Running test: #{lib-name}/#{name}"
        run-test "#{lib-name}/#{name}", test    
    console.log "... End of #{lib-name}"
