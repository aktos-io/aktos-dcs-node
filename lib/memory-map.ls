require! 'prelude-ls': {split, keys, map}
require! './keypath': {get-keypath}
``
function hex2float (a) {return (a & 0x7fffff | 0x800000) * 1.0 / Math.pow(2,23) * Math.pow(2,  ((a>>23 & 0xff) - 127))}


function bit_test(num, bit){
    return ((num>>bit) % 2 != 0)
}

function bit_set(num, bit){
    return num | 1<<bit;
}

function bit_clear(num, bit){
    return num & ~(1<<bit);
}

function bit_toggle(num, bit){
    return bit_test(num, bit) ? bit_clear(num, bit) : bit_set(num, bit);
}

``

export bit-test = bit_test
export bit-write = (source, bit-num, value) ->
    if value
        bit_set source, bit-num
    else
        bit_clear source, bit-num

export dec2bin = (dec) ->
    '''
    dec2bin(1);    // 1
    dec2bin(-1);   // 11111111111111111111111111111111
    dec2bin(256);  // 100000000
    dec2bin(-256); // 11111111111111111111111100000000
    '''
    dec .>>>. 0 .to-string 2

data-types =
    # integer
    int: (x) -> parse-int x

    # hex representation of an integer number
    hex: (x) -> x.to-string 16 .to-upper-case!

    # hex representation of float number
    hexf: hex2float

    # the stored value in memory is 1000 times of actual value
    mili: (/1000)

    # bool
    #bool: ...


example-memory-map =
    'test-level-1':
        addr: \MD84
        type: \hexf

    'test-level-2'
        addr: \MD85
        type: \hexf

export class IoHandle
    (opts={})->
        @topic = opts.topic
        @address = opts.address
        @type = null

    get-actual: (value) ->
        unless @type
            ...
        data-types[@type] value

export class MemoryMap
    (opts) ->
        @table = opts.table or throw "Io Table is required."
        @namespace = opts.namespace or throw "Namespace required."
        @handles = []
        for io, params of get-keypath @table, @namespace
            @handles.push new IoHandle do
                topic: "#{@namespace}.#{io}"
                address: params.address

    get-handles: ->
        @handles


/* tests
----------------------------
export io-map = new MemoryMap do
    io:
        plc1:
            motor1:
                address: 'C100.01'
                dir: \out
                type: \bool

# io-map.address-of 'motor1' # => "C100.01"
console.log "address of io.plc1.motor1:", io-map.address-of 'io.plc1.motor1'
*/
