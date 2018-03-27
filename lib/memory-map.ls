require! 'prelude-ls': {split}
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


export class MemoryMap
    (@table) ->

    get-actual: (addr, value) ->
        for io of @table when io.addr is addr
            return do
                value: data-types[io.type] value
