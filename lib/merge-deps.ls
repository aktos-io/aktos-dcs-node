require! './merge': {merge}
require! './packing': {clone}
require! './test-utils': {make-tests}
require! './get-with-keypath': {get-with-keypath}
require! 'prelude-ls': {empty, Obj, unique, keys, find, union}
require! './apply-changes': {apply-changes}
require! './diff-deps': {diff-deps}

# re-export
export apply-changes
export diff-deps

export class DependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, DependencyError)

export class CircularDependencyError extends Error
    (@message, @dependency) ->
        super ...
        Error.captureStackTrace(this, CircularDependencyError)



export merge-deps = (doc, keypath, dep-sources={}, opts={}) ->
    [arr-path, search-path] = keypath.split '.*.'

    doc = apply-changes doc

    const dep-arr = doc `get-with-keypath` arr-path


    unless Obj.empty dep-arr
        for index of dep-arr
            dep-name = dep-arr[index] `get-with-keypath` search-path
            continue unless dep-name

            # this key-value pair has further dependencies
            if typeof! dep-sources[dep-name] is \Object
                dep-source = if dep-sources[dep-name]
                    clone that
                else
                    {}
            else
                throw new DependencyError("merge-deps: Required dependency is not found:", dep-name)

            if typeof! (dep-source `get-with-keypath` arr-path) is \Object
                # if dependency-source has further dependencies,
                # merge recursively
                dep-source = merge-deps dep-source, keypath, dep-sources, {+calc-changes}

            # ------------------------------------------------------------
            # we have fully populated dependency-source at this point
            # ------------------------------------------------------------

            for k of dep-arr[index]
                if k of dep-source
                    dep-arr[index]
            dep-arr[index] = dep-source <<< dep-arr[index]

    return doc

export bundle-deps = (doc, deps) ->
    return {doc, deps}

export patch-changes = (diff, changes) ->
    return diff unless changes

    for k, v of diff
        if typeof! v is \Object
            v = patch-changes v, changes[k]
        changes[k] = v

# ----------------------- TESTS ------------------------------------------
make-tests \merge-deps, do
    'simple': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo

        dependencies =
            foo:
                _id: 'foo'
                hello: 'there'

        return do
            result: merge-deps doc, \deps.*.key, dependencies
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        _id: 'foo'
                        hello: 'there'
                        key: \foo

    'simple with extra changes': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
            changes:
                deps:
                    hey:
                        there: \hello

        dependencies =
            foo:
                _id: 'foo'
                hello: 'there'

        return do
            result: merge-deps doc, \deps.*.key, dependencies
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    my:
                        _id: 'foo'
                        hello: 'there'
                        key: \foo

                changes:
                    deps:
                        hey:
                            there: \hello


    'one dependency used in multiple locations': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my1:
                    key: 'foo'

        deps =
            foo:
                _id: 'foo'
                hello: 'there'
                deps:
                    hey:
                        key: \baz
                    hey2:
                        key: \qux
            baz:
                _id: 'baz'
                deps:
                    hey3:
                        key: \qux
            qux:
                _id: 'qux'
                hello: 'world'

        return do
            result: merge-deps doc, \deps.*.key , deps
            expect:
                _id: 'bar'
                nice: 'day'
                deps:
                    my1:
                        key: \foo
                        _id: 'foo'
                        hello: 'there'
                        deps:
                            hey:
                                key: \baz
                                _id: 'baz'
                                deps:
                                    hey3:
                                        key: \qux
                                        _id: 'qux'
                                        hello: 'world'

                            hey2:
                                key: \qux
                                _id: 'qux'
                                hello: 'world'
    'circular dependency': ->
        return false

    'missing dependency': ->
        doc =
            deps:
                my:
                    key: \foo

        dependencies =
            bar:
                _id: 'bar'
                hello: 'there'

        expect (-> merge-deps doc, \deps.*.key, dependencies)
            .to-throw "merge-deps: Required dependency is not found:"



    'changed remote document': ->
        doc =
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
            changes:
                deps:
                    my:
                        hi: \world

        dependencies =
            foo:
                _id: 'foo'
                hello: 'there'
                deps:
                    my1:
                        key: \foo-dep

            'foo-dep':
                _id: 'foo-dep'
                eating: 'seed'

        merged = merge-deps doc, \deps.*.key, dependencies

        expect merged
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: \foo
                    _id: 'foo'
                    hello: 'there'
                    hi: \world
                    deps:
                        my1:
                            key: \foo-dep
                            _id: 'foo-dep'
                            eating: 'seed'

            changes:
                deps:
                    my:
                        hi: \world

        # change a remote dependency in the tree
        merged.changes.deps.my.key = 'roadrunner'

        # add this dependency to the dependency sources
        dependencies.roadrunner =
            _id: 'roadrunner'
            its: 'working'
            deps:
                my1:
                    key: 'coyote'
                    value: 3

        dependencies.coyote =
            _id: 'coyote'
            name: 'coyote who runs behind roadrunner'

        # just to be sure that changes are correct
        expect merged.changes.deps.my
        .to-equal do
            hi: \world
            key: \roadrunner

        expect merge-deps merged, \deps.*.key, dependencies
        .to-equal do
            _id: 'bar'
            nice: 'day'
            deps:
                my:
                    key: 'roadrunner'
                    _id: 'roadrunner'
                    its: 'working'
                    hi: \world
                    deps:
                        my1:
                            key: 'coyote'
                            value: 3
                            _id: 'coyote'
                            name: 'coyote who runs behind roadrunner'
            changes:
                deps:
                    my:
                        key: 'roadrunner'
                        hi: \world

    'changed remote document (2)': ->
        input =
            {
              "_id": "Harici Pano 2",
              "_rev": "6-7b6a02337344c8c00cc36f0830fe21f2",
              "type": "component",
              "class": null,
              "components": {
                "Arka Kapak": {
                  "key": "Civatalı Kapak"
                },
                "Yan Kapak": {
                  "key": "Kaynaklı Kapak"
                }
              },
              "description": "",
              "netsis": "",
              "labels": "",
              "countable": true,
              "timestamp": 1510656568123,
              "owner": "mustafa",
              "changes": {
                "components": {
                  "Arka Kapak": {
                    "key": "Kaynaklı Kapak",
                    "components": {
                      "SAC (2MM)": {
                        "key": "SAC (2MM)"
                      },
                      "Gazaltı Kaynağı": {
                        "value": null
                      }
                    }
                  },
                  "Yan Kapak": {}
                }
              }
            }

        deps =
            {
              "Civatalı Kapak": {
                "_id": "Civatalı Kapak",
                "_rev": "1-66245aeba4354d3ca414d300a0a4a937",
                "type": "component",
                "class": null,
                "components": {
                  "CIVATA (M5)": {
                    "key": "CIVATA (M5)"
                  },
                  "SAC (2MM)": {
                    "key": "SAC (2MM)"
                  }
                },
                "description": "",
                "netsis": "",
                "labels": "",
                "countable": true,
                "changes": {},
                "timestamp": 1510656523323,
                "owner": "mustafa"
              },
              "Kaynaklı Kapak": {
                "_id": "Kaynaklı Kapak",
                "_rev": "3-b98cd73aaf850cdcc49a08d0e7c98fa4",
                "type": "component",
                "class": null,
                "components": {
                  "SAC (2MM)": {
                    "key": "SAC (2MM)"
                  },
                  "Gazaltı Kaynağı": {
                    "key": "Gazaltı Kaynağı"
                  }
                },
                "description": "",
                "netsis": "",
                "labels": "",
                "countable": true,
                "changes": {
                  "components": {
                    "SAC (2MM)": {},
                    "Gazaltı Kaynağı": {
                      "amount": 30
                    }
                  }
                },
                "timestamp": 1510656671542,
                "owner": "mustafa"
              },
              "CIVATA (M5)": {
                "_id": "CIVATA (M5)",
                "_rev": "6-e4ead009bb314aa5081c206ebb33118b",
                "type": "component",
                "class": "bolt",
                "properties": {},
                "timestamp": 1508594085355,
                "owner": "cca",
                "components": {},
                "description": "",
                "netsis": "",
                "labels": "",
                "countable": true
              },
              "SAC (2MM)": {
                "_id": "SAC (2MM)",
                "_rev": "3-fc19a52e507928a20d3cd7c114caecc0",
                "type": "component",
                "class": "plate",
                "properties": {},
                "timestamp": 1508594044448,
                "owner": "cca",
                "description": "",
                "netsis": "",
                "labels": "",
                "countable": true
              },
              "Gazaltı Kaynağı": {
                "_id": "Gazaltı Kaynağı",
                "_rev": "2-595d52647827827415902ae13da29568",
                "type": "component",
                "class": null,
                "components": {
                  "Kaynak Gazı": {
                    "key": "Co2"
                  },
                  "Gazaltı Teli": {
                    "key": "Gazaltı Teli"
                  }
                },
                "description": "1/cm*mm",
                "netsis": "",
                "labels": "",
                "countable": true,
                "changes": {
                  "components": {
                    "Kaynak Gazı": {
                      "amount": 0.00001
                    },
                    "Gazaltı Teli": {
                      "amount": 3
                    }
                  }
                },
                "timestamp": 1510656826072,
                "owner": "mustafa"
              },
              "Co2": {
                "_id": "Co2",
                "_rev": "1-73733fde5cbc07625bc805908e74b2ed",
                "type": "component",
                "class": null,
                "components": {},
                "description": "",
                "netsis": "",
                "labels": "",
                "countable": true,
                "timestamp": 1510656687156,
                "owner": "mustafa"
              },
              "Gazaltı Teli": {
                "_id": "Gazaltı Teli",
                "_rev": "1-8456407dfeb21a2ee5e9d2e6f5af52c2",
                "type": "component",
                "class": null,
                "components": {},
                "description": "",
                "netsis": "",
                "labels": "",
                "countable": true,
                "timestamp": 1510656714784,
                "owner": "mustafa"
              }
            }

        output =
            {
              "_id": "Harici Pano 2",
              "_rev": "6-7b6a02337344c8c00cc36f0830fe21f2",
              "type": "component",
              "class": null,
              "components": {
                "Arka Kapak": {
                  "_id": "Kaynaklı Kapak",
                  "_rev": "3-b98cd73aaf850cdcc49a08d0e7c98fa4",
                  "type": "component",
                  "class": null,
                  "components": {
                    "SAC (2MM)": {
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "value": null
                    }
                  },
                  "description": "",
                  "netsis": "",
                  "labels": "",
                  "countable": true,
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "timestamp": 1510656671542,
                  "owner": "mustafa",
                  "key": "Kaynaklı Kapak"
                },
                "Yan Kapak": {
                  "_id": "Kaynaklı Kapak",
                  "_rev": "3-b98cd73aaf850cdcc49a08d0e7c98fa4",
                  "type": "component",
                  "class": null,
                  "components": {
                    "SAC (2MM)": {
                      "_id": "SAC (2MM)",
                      "_rev": "3-fc19a52e507928a20d3cd7c114caecc0",
                      "type": "component",
                      "class": "plate",
                      "properties": {},
                      "timestamp": 1508594044448,
                      "owner": "cca",
                      "description": "",
                      "netsis": "",
                      "labels": "",
                      "countable": true,
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "_id": "Gazaltı Kaynağı",
                      "_rev": "2-595d52647827827415902ae13da29568",
                      "type": "component",
                      "class": null,
                      "components": {
                        "Kaynak Gazı": {
                          "_id": "Co2",
                          "_rev": "1-73733fde5cbc07625bc805908e74b2ed",
                          "type": "component",
                          "class": null,
                          "components": {},
                          "description": "",
                          "netsis": "",
                          "labels": "",
                          "countable": true,
                          "timestamp": 1510656687156,
                          "owner": "mustafa",
                          "key": "Co2",
                          "amount": 0.00001
                        },
                        "Gazaltı Teli": {
                          "_id": "Gazaltı Teli",
                          "_rev": "1-8456407dfeb21a2ee5e9d2e6f5af52c2",
                          "type": "component",
                          "class": null,
                          "components": {},
                          "description": "",
                          "netsis": "",
                          "labels": "",
                          "countable": true,
                          "timestamp": 1510656714784,
                          "owner": "mustafa",
                          "key": "Gazaltı Teli",
                          "amount": 3
                        }
                      },
                      "description": "1/cm*mm",
                      "netsis": "",
                      "labels": "",
                      "countable": true,
                      "changes": {
                        "components": {
                          "Kaynak Gazı": {
                            "amount": 0.00001
                          },
                          "Gazaltı Teli": {
                            "amount": 3
                          }
                        }
                      },
                      "timestamp": 1510656826072,
                      "owner": "mustafa",
                      "key": "Gazaltı Kaynağı",
                      "amount": 30
                    }
                  },
                  "description": "",
                  "netsis": "",
                  "labels": "",
                  "countable": true,
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "timestamp": 1510656671542,
                  "owner": "mustafa",
                  "key": "Kaynaklı Kapak"
                }
              },
              "description": "",
              "netsis": "",
              "labels": "",
              "countable": true,
              "timestamp": 1510656568123,
              "owner": "mustafa",
              "changes": {
                "components": {
                  "Arka Kapak": {
                    "key": "Kaynaklı Kapak",
                    "components": {
                      "SAC (2MM)": {
                        "key": "SAC (2MM)"
                      },
                      "Gazaltı Kaynağı": {
                        "value": null
                      }
                    }
                  },
                  "Yan Kapak": {}
                }
              }
            }

        expect output
        .to-equal doc =
            {
              "_id": "Harici Pano 2",
              "_rev": "6-7b6a02337344c8c00cc36f0830fe21f2",
              "type": "component",
              "class": null,
              "components": {
                "Arka Kapak": {
                  "_id": "Kaynaklı Kapak",
                  "_rev": "3-b98cd73aaf850cdcc49a08d0e7c98fa4",
                  "type": "component",
                  "class": null,

                  "components": {
                    "SAC (2MM)": {
                      "_id": "SAC (2MM)",
                      "_rev": "3-fc19a52e507928a20d3cd7c114caecc0",
                      "type": "component",
                      "class": "plate",
                      "properties": {},
                      "timestamp": 1508594044448,
                      "owner": "cca",
                      "description": "",
                      "netsis": "",
                      "labels": "",
                      "countable": true,
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "_id": "Gazaltı Kaynağı",
                      "_rev": "2-595d52647827827415902ae13da29568",
                      "type": "component",
                      "class": null,
                      "components": {
                        "Kaynak Gazı": {
                          "_id": "Co2",
                          "_rev": "1-73733fde5cbc07625bc805908e74b2ed",
                          "type": "component",
                          "class": null,
                          "components": {},
                          "description": "",
                          "netsis": "",
                          "labels": "",
                          "countable": true,
                          "timestamp": 1510656687156,
                          "owner": "mustafa",
                          "key": "Co2",
                          "amount": 0.00001
                        },
                        "Gazaltı Teli": {
                          "_id": "Gazaltı Teli",
                          "_rev": "1-8456407dfeb21a2ee5e9d2e6f5af52c2",
                          "type": "component",
                          "class": null,
                          "components": {},
                          "description": "",
                          "netsis": "",
                          "labels": "",
                          "countable": true,
                          "timestamp": 1510656714784,
                          "owner": "mustafa",
                          "key": "Gazaltı Teli",
                          "amount": 3
                        }
                      },
                      "description": "1/cm*mm",
                      "netsis": "",
                      "labels": "",
                      "countable": true,
                      "changes": {
                        "components": {
                          "Kaynak Gazı": {
                            "amount": 0.00001
                          },
                          "Gazaltı Teli": {
                            "amount": 3
                          }
                        }
                      },
                      "timestamp": 1510656826072,
                      "owner": "mustafa",
                      "key": "Gazaltı Kaynağı",
                      "amount": 30
                    }
                  },

                  "description": "",
                  "netsis": "",
                  "labels": "",
                  "countable": true,
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "timestamp": 1510656671542,
                  "owner": "mustafa",
                  "key": "Kaynaklı Kapak"
                },
                "Yan Kapak": {
                  "_id": "Kaynaklı Kapak",
                  "_rev": "3-b98cd73aaf850cdcc49a08d0e7c98fa4",
                  "type": "component",
                  "class": null,
                  "components": {
                    "SAC (2MM)": {
                      "_id": "SAC (2MM)",
                      "_rev": "3-fc19a52e507928a20d3cd7c114caecc0",
                      "type": "component",
                      "class": "plate",
                      "properties": {},
                      "timestamp": 1508594044448,
                      "owner": "cca",
                      "description": "",
                      "netsis": "",
                      "labels": "",
                      "countable": true,
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "_id": "Gazaltı Kaynağı",
                      "_rev": "2-595d52647827827415902ae13da29568",
                      "type": "component",
                      "class": null,
                      "components": {
                        "Kaynak Gazı": {
                          "_id": "Co2",
                          "_rev": "1-73733fde5cbc07625bc805908e74b2ed",
                          "type": "component",
                          "class": null,
                          "components": {},
                          "description": "",
                          "netsis": "",
                          "labels": "",
                          "countable": true,
                          "timestamp": 1510656687156,
                          "owner": "mustafa",
                          "key": "Co2",
                          "amount": 0.00001
                        },
                        "Gazaltı Teli": {
                          "_id": "Gazaltı Teli",
                          "_rev": "1-8456407dfeb21a2ee5e9d2e6f5af52c2",
                          "type": "component",
                          "class": null,
                          "components": {},
                          "description": "",
                          "netsis": "",
                          "labels": "",
                          "countable": true,
                          "timestamp": 1510656714784,
                          "owner": "mustafa",
                          "key": "Gazaltı Teli",
                          "amount": 3
                        }
                      },
                      "description": "1/cm*mm",
                      "netsis": "",
                      "labels": "",
                      "countable": true,
                      "changes": {
                        "components": {
                          "Kaynak Gazı": {
                            "amount": 0.00001
                          },
                          "Gazaltı Teli": {
                            "amount": 3
                          }
                        }
                      },
                      "timestamp": 1510656826072,
                      "owner": "mustafa",
                      "key": "Gazaltı Kaynağı",
                      "amount": 30
                    }
                  },
                  "description": "",
                  "netsis": "",
                  "labels": "",
                  "countable": true,
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "timestamp": 1510656671542,
                  "owner": "mustafa",
                  "key": "Kaynaklı Kapak"
                }
              },
              "description": "",
              "netsis": "",
              "labels": "",
              "countable": true,
              "timestamp": 1510656568123,
              "owner": "mustafa",
              "changes": {
                "components": {
                  "Arka Kapak": {
                    "key": "Kaynaklı Kapak",
                    "components": {
                      "SAC (2MM)": {
                        "key": "SAC (2MM)"
                      },
                      "Gazaltı Kaynağı": {
                        "value": null
                      }
                    }
                  },
                  "Yan Kapak": {}
                }
              }
            }
