class SingletonExample
    @instance = null
    ->
        # Make this class Singleton
        return @@instance if @@instance
        @@instance = this

        ...
