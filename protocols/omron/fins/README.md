To overwrite message format:

        class MyPLC extends OmronFinsClient
            action: ->
                # implement your message format here


new MyPLC {name: \io.plc1, io-map}
