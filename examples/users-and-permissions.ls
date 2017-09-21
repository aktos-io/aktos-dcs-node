require! '../src/auth-helpers': {hash-passwd}

export users =
    * _id: 'user1'
      passwd-hash: hash-passwd "hello world"
      roles:
          'test-area-writer'

    * _id: 'user2'
      passwd-hash: hash-passwd "hello world2"
      roles:
          \test-area-writer


export permissions =
    * _id: \test-area-reader
      ro: \authorization.test1

    * _id: \test-area-writer
      inherits:
          \test-area-reader
      rw:
          \authorization.test1

    * _id: \my-test-role
      ro:
          'my-test-topic1'
          'my-test-topic2'
      rw:
          'my-test-topic-rw3'

    * _id: \my-test-role2
      inherits:
          \my-test-role
          \test-area-writer
      rw:
          'my-test-topicrw4'
