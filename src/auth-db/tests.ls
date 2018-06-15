require! '../../lib/test-utils': {make-tests}
require! './auth-db': {AuthDB}

users =
    'cca':
        passwd-hash: 123
        groups: <[ me him ]>
        opening-scene: \orders
        hello: \baby

    'me':
        hey: \first

    'him':
        hey: \second

    'foo':
        hey: 'me'
        groups: <[ me him foo-like ]>
        routes:
            \@hello.there

    'foo-like':
        routes:
            \world.is.great
            ...

    'bar':
        groups: <[ foo ]>
        routes:
            \!world.is.great
            ...

    'baz':
        groups: <[ foo ]>
        routes:
            \!world.is.great
            ...
        permissions:
            \db.own-clients
            \plc.input

    'qux':
        groups: <[ baz ]>
        permissions:
            \!db.*
            ...

    'to-exclude':
        routes:
            \plc1.**

    'coyote':
        groups:
            \qux
            \!to-exclude
        routes:
            \plc1.io1

    'db-proxy':
        routes:
            \@db-proxy.**

    'my-other-user':
        groups:
            \db-proxy


auth = new AuthDB users

make-tests 'AuthDB Tests', do
    'simple': ->
        expect auth.get \cca
        .to-equal do
            _id: \cca
            passwd-hash: 123
            groups: <[ me him ]>
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
            groups: <[ me him foo-like ]>
            hey: \me
            routes:
                \@foo.**
                \world.is.great
                \@hello.there

    'route-exclusion': ->
        expect auth.get \bar
        .to-equal do
            _id: \bar
            groups: <[ me him foo-like foo ]>
            hey: \me
            routes:
                \@bar.**
                \@hello.there

    'permissions': ->
        expect auth.get \baz
        .to-equal do
            _id: \baz
            groups: <[ me him foo-like foo ]>
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
            groups: <[ me him foo-like foo baz ]>
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
            groups: <[ me him foo-like foo baz qux !to-exclude ]>
            hey: \me
            routes:
                \@coyote.**
                \@hello.there
            permissions:
                \plc.input
                ...

    'special routes': ->
        expect auth.get \my-other-user
        .to-equal do
            _id: \my-other-user
            groups: <[ db-proxy ]>
            routes:
                \@my-other-user.**
                \@db-proxy.**
