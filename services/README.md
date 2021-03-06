# Description

Connectors are the actors that provides a proper communication with the outside of the process.

# Connector Design

```
 ______________________________________________________________________________________
| PHYSICAL DEVICE / DATABASE / PLC / BROWSER / ANOTHER DCS NETWORK / WEBSERVICE / ...  |
|______________________________________________________________________________________|

                                   ^^^
                                   |||
                                   |||
                                   vvv             \
                            _________________        \
                           |   Transport     |        |
                           |-----------------|        |
                           |    Protocol?    |         > Connector
                           |-----------------|        |
                           |  Protocol Actor |        |
                           |_________________|        |
                                    ^                /
                                    |              /
                                    v
                           ~~~~~~~~~~~~~~~~~~~~
                           |   DCS NETWORK    |
                           ~~~~~~~~~~~~~~~~~~~~
```

| Term | Necessity | Definition |
| --- | --- | --- |  
| Transport | Required | A physical transport media (serial, usb, ethernet, wifi, sound card, ...)|
| Protocol | Optional | Protocol that converts the dcs-message format for the physical/target device/system. (Transparent, Modbus, AT Commands, Hostlink, ...) |
| Protocol Actor | Required | An actor with standardized message payload format |
