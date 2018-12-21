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
