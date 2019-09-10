# Interfacing with a device 

1. Create `YourDriver` by extending `DriverAbstract` class. See its README.
2. Declare the necessary handles for your device.
3. Create `IoProxyHandler` for each handle by using appropriate driver, eg: 

        ser = new SerialPortTransport({port: '/dev/ttyUSB0'})
        
        devices = 
            meter1:
                driver: IEC6256_25_Driver
                driver-params: 
                    transport: ser
                handles: <[ 
                        serial_no
                        time
                        date                    
                        import_active            
                        import_inductive         
                        import_capacitive        
                        export_active            
                        export_inductive         
                        export_capacitive       
                        demand
                        ]>

        for device-name, device of devices
            driver = new device.driver(device.driver-params <<< {name: device-name})
            for io-name in device.handles
                args = {code: IEC6256_25.obis-by-name[io-name]}
                handle = new IoHandle args, "@#{user-name}.#{device-name}.#{io-name}"
                new IoProxyHandler handle, driver

4. `trigger 'data'` within `YourDriver` to broadcast values. 
5. Create an instance of `DcsTcpClient` and connect the node to your DCS network.