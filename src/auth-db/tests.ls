require! '../lib/test-utils': {make-tests}
require! './auth-db': {auth-db}

users =
    'cca':
        passwd-hash: 123
        roles: <[ me him ]>
        opening-scene: \orders
        hello: \baby

    'me':
        hey: \first

    'him':
        hey: \second

    'foo':
        hey: 'me'
        roles: <[ me him foo-like ]>
        routes:
            \@hello.there

    'foo-like':
        routes:
            \world.is.great
            ...

    'bar':
        roles: <[ foo ]>
        routes:
            \!world.is.great
            ...

    'baz':
        roles: <[ foo ]>
        routes:
            \!world.is.great
            ...
        permissions:
            \db.own-clients
            \plc.input

    'qux':
        roles: <[ baz ]>
        permissions:
            \!db.*
            ...

    'to-exclude':
        routes:
            \plc1.**

    'coyote':
        roles:
            \qux
            \!to-exclude
        routes:
            \plc1.io1


auth = new AuthDB users

make-tests 'AuthDB Tests', do
    'simple': ->
        expect auth.get \cca
        .to-equal do
            _id: \cca
            passwd-hash: 123
            roles: <[ me him ]>
            opening-scene: \orders
            hey: \second
            hello: \baby
            routes:
                \@cca.**
                ...

    'simple2': ->
        expect auth.get \foo
        .to-equal do
            _id: \foo
            roles: <[ me him foo-like ]>
            hey: \me
            routes:
                \@foo.**
                \world.is.great
                \@hello.there

    'route-exclusion': ->
        expect auth.get \bar
        .to-equal do
            _id: \bar
            roles: <[ me him foo-like foo ]>
            hey: \me
            routes:
                \@bar.**
                \@hello.there

    'permissions': ->
        expect auth.get \baz
        .to-equal do
            _id: \baz
            roles: <[ me him foo-like foo ]>
            hey: \me
            routes:
                \@baz.**
                \@hello.there
            permissions:
                \db.own-clients
                \plc.input

    'wildcard exclusion': ->
        expect auth.get \qux
        .to-equal do
            _id: \qux
            roles: <[ me him foo-like foo baz ]>
            hey: \me
            routes:
                \@qux.**
                \@hello.there
            permissions:
                \plc.input
                ...

    'role exclusion': ->
        expect auth.get \coyote
        .to-equal do
            _id: \coyote
            roles: <[ me him foo-like foo baz qux !to-exclude ]>
            hey: \me
            routes:
                \@coyote.**
                \@hello.there
            permissions:
                \plc.input
                ...
