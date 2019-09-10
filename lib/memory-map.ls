require! 'prelude-ls': {split, keys, map}
require! './keypath': {get-keypath}
require! '../src/errors': {CodingError}

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

``
// taken from https://stackoverflow.com/a/1268377/1952991
function zeroPad(num, numZeros) {
    var n = Math.abs(num);
    var zeros = Math.max(0, numZeros - Math.floor(n).toString().length );
    var zeroString = Math.pow(10,zeros).toString().substr(1);
    if( num < 0 ) {
        zeroString = '-' + zeroString;
    }

    return zeroString+n;
}
``
export zero-pad

export split-bits = (input) ->
    # returns binary array
    # [input.0(lsb), input.1, input.2, ..., input.7(msb)]
    bin = (+input).to-string 2
    zpad8 = -> "00000000#{it}".slice -8
    bin |> zpad8 |> (-> it.split "" .reverse! .map (.trim! |> parse-int))


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
    bool: (Boolean)


export class IoHandle
    '''
    This class adds some useful methods to an IO object, such as: 

        .get-meaningful(raw-value): Returns meaningful value
                                    regarding to the @type. 
    '''
    (opts={}, route)->
        # add all properties as if they exists in IoHandle
        for k, v of opts
            this[k] = v
        @route = route
        @id = @route 


    get-meaningful: (value) ->
        if typeof! @converter
            @converter value 
        else 
            unless @type
                ...
            data-types[@type] value

    register-converter: (converter) -> 
        # `converter`   : Converts from raw value to meaningful value
        #                 and vice versa 
        # 
        # Params        : converter(value, reverse=false)
        @converter = converter 


export parse-io-addr = (full-name) ->
    # "x5.3" => {prefix: "x", byte: 5, bit: 3}
    [prefix, byte, bit-sep, bit] = full-name.split /(\d+)/
    parsed =
        prefix: prefix
        byte: parse-int(byte),
        bit: if bit-sep => parse-int bit else null
        bool: if bit-sep => yes else no
    return parsed

export make-io-addr = (prefix, byte, bit) ->
    # x, 3, 5 => "x3.5"
    # x, 4 => "x4"
    "#{prefix}#{byte}#{if bit then ".#{bit}"}"

export class BlockRead
    (opts) ->
        @prefix = opts.prefix
        @from = opts.from
        @count = opts.count
        @bits0 = [] # previous states
        @bits = []
        @handlers = {}

    read-params: ~
        -> [@prefix, @from, @count]

    add-handler: (name, handler) ->
        if name of @handlers
            console.error "#{name} is already registered, not registering again."
        else
            @handlers[name] = handler

    distribute: (arr) !->
        @bits.length = 0
        for arr
            @bits.push split-bits ..

        for i of @bits
            for j of @bits[i]
                if @bits[i][j] isnt @bits0[i]?[j]
                    #console.log "bit #{i}#{j} is changed to: ", @bits[i][j]
                    addr = make-io-addr @prefix, i, j
                    @handlers[addr]? err=null, @bits[i][j]

        @bits0 = JSON.parse JSON.stringify @bits
