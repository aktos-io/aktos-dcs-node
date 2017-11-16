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
              "components": {
                "Arka Kapak": {
                  "key": "Civatalı Kapak"
                },
                "Yan Kapak": {
                  "key": "Kaynaklı Kapak"
                }
              },
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
                "components": {
                  "CIVATA (M5)": {
                    "key": "CIVATA (M5)"
                  },
                  "SAC (2MM)": {
                    "key": "SAC (2MM)"
                  }
                },
                "changes": {},
              },
              "Kaynaklı Kapak": {
                "components": {
                  "SAC (2MM)": {
                    "key": "SAC (2MM)"
                  },
                  "Gazaltı Kaynağı": {
                    "key": "Gazaltı Kaynağı"
                  }
                },
                "changes": {
                  "components": {
                    "SAC (2MM)": {},
                    "Gazaltı Kaynağı": {
                      "amount": 30
                    }
                  }
                }
              },
              "CIVATA (M5)": {
                "components": {}
              },
              "SAC (2MM)": {
              },
              "Gazaltı Kaynağı": {
                "components": {
                  "Kaynak Gazı": {
                    "key": "Co2"
                  },
                  "Gazaltı Teli": {
                    "key": "Gazaltı Teli"
                  }
                },
                "changes": {
                  "components": {
                    "Kaynak Gazı": {
                      "amount": 0.00001
                    },
                    "Gazaltı Teli": {
                      "amount": 3
                    }
                  }
                }
              },
              "Co2": {
                "components": {}
              },
              "Gazaltı Teli": {
                "components": {}
              }
            }

        output =
            {
              "components": {
                "Arka Kapak": {
                  "components": {
                    "SAC (2MM)": {
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "value": null
                    }
                  },
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "key": "Kaynaklı Kapak"
                },
                "Yan Kapak": {
                  "components": {
                    "SAC (2MM)": {
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "components": {
                        "Kaynak Gazı": {
                          "components": {},
                          "key": "Co2",
                          "amount": 0.00001
                        },
                        "Gazaltı Teli": {
                          "components": {},
                          "key": "Gazaltı Teli",
                          "amount": 3
                        }
                      },
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
                      "key": "Gazaltı Kaynağı",
                      "amount": 30
                    }
                  },
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "key": "Kaynaklı Kapak"
                }
              },
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
              "components": {
                "Arka Kapak": {
                  "components": {
                    "SAC (2MM)": {
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "components": {
                        "Kaynak Gazı": {
                          "components": {},
                          "key": "Co2",
                          "amount": 0.00001
                        },
                        "Gazaltı Teli": {
                          "components": {},
                          "key": "Gazaltı Teli",
                          "amount": 3
                        }
                      },
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
                      "key": "Gazaltı Kaynağı",
                      "amount": 30
                    }
                  },
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "key": "Kaynaklı Kapak"
                },
                "Yan Kapak": {
                  "components": {
                    "SAC (2MM)": {
                      "key": "SAC (2MM)"
                    },
                    "Gazaltı Kaynağı": {
                      "components": {
                        "Kaynak Gazı": {
                          "components": {},
                          "key": "Co2",
                          "amount": 0.00001
                        },
                        "Gazaltı Teli": {
                          "components": {},
                          "key": "Gazaltı Teli",
                          "amount": 3
                        }
                      },
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
                      "key": "Gazaltı Kaynağı",
                      "amount": 30
                    }
                  },
                  "changes": {
                    "components": {
                      "SAC (2MM)": {},
                      "Gazaltı Kaynağı": {
                        "amount": 30
                      }
                    }
                  },
                  "key": "Kaynaklı Kapak"
                }
              },
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
