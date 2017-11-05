``
// taken from https://stackoverflow.com/a/2736070/1952991 by cca
deepCompare = function(x){
    for (var p in this) {
        if(typeof(this[p]) !== typeof(x[p])) return false;
        if((this[p]===null) !== (x[p]===null)) return false;
        switch (typeof(this[p])) {
            case 'undefined':
                if (typeof(x[p]) != 'undefined') return false;
                break;
            case 'object':
                if(this[p]!==null && x[p]!==null && (this[p].constructor.toString() !== x[p].constructor.toString() || !this[p].equals(x[p]))) return false;
                break;
            case 'function':
                if (p != 'equals' && this[p].toString() != x[p].toString()) return false;
                break;
            default:
                if (this[p] !== x[p]) return false;
        }
    }
    return true;
}
``
export make-tests = (lib-name, tests) ->
    if typeof! lib-name is \Object
        tests = lib-name
        lib-name = \Tests

    console.log "++++++++++ Start of tests: #{lib-name}"
    for name, test of tests
        res = test!
        unless res
            console.log "Test [#{name}] is skipped..."
            continue

        try
            expected = JSON.stringify(res.expect)
            result = JSON.stringify(res.result)
            if deep-compare res.result, res.expect
                console.error   "- FAILED on test: #{name}"
                console.log     "- result  \t: ", result
                console.log     "- expected\t: ", expected
            else
                console.log "...passed from test: #{name}."
        catch
            debugger
    console.log "End of tests."
