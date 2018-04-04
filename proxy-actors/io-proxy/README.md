# IoProxyHandler

## Events:

    read handle, respond(err, value)

    write handle, value, respond(err)

handle Object:

    address: Original address representation
    type: bool, int, ...

## Request Message Format

    ..write:
        payload: {val: newValue}

    ..read:
        payload: null

## Response Message Format:

    ..read
        err: error if there are any
        res:
            curr: current value
            prev: previous value

    ..write (see read response)

## Example: (see PhysicalTargetSimulator)
