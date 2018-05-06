Users are also roles (groups). Fields are:

    'my-user':
        password-hash: sha512 of password (optional, can not login if this field is
            omitted, thus it is a role/group name only)

        roles: Array of role names to inherit

            'some-role'
            'some-other-role' # or user
            '!some-restricted-role' # exclude some-restricted-role's routes

        routes: Array of routes that the user can communicate with

            'some-topic.some-child.*'   # => send/receive to/from that topic along with other subscribers
            '@some-user.**'              # => communicate only with @some-user
                                             login username should match in order to
                                             receive this messages.
            '!some-other-topic.**'     # => disable for that route

        permissions: Array of domain specific permissions/filter names.
            In order to negate the filter, prepend "!" to the beginning.

            'db.own-clients'
            'db.production-job'
            '!db.get.design-docs'
            '!db.put.design-docs'

            > Applications are responsible for filtering their output by taking these
            > filters into account.
