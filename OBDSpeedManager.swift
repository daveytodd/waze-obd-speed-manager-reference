import CoreBluetooth

class OBDSpeedManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var central: CBCentralManager!
    var obdPeripheral: CBPeripheral?
    var rxChar: CBCharacteristic?
    var txChar: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        if peripheral.name?.contains("OBD") == true || peripheral.name?.contains("V-LINK") == true {
            obdPeripheral = peripheral
            central.stopScan()
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                txChar = char
            }
            if char.properties.contains(.notify) {
                rxChar = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        sendSpeedQuery()
    }

    func sendSpeedQuery() {
        guard let tx = txChar, let peripheral = obdPeripheral else { return }
        let cmd = "010D\r".data(using: .ascii)!
        peripheral.writeValue(cmd, for: tx, type: .withoutResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let response = String(data: data, encoding: .ascii) else { return }
        let clean = response.replacingOccurrences(of: " ", with: "")
        if let range = clean.range(of: "410D") {
            let hexStart = range.upperBound
            let hexEnd = clean.index(hexStart, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            let speedHex = String(clean[hexStart..<hexEnd])
            if let speedKmh = Int(speedHex, radix: 16) {
                print("Live vehicle speed: \(speedKmh) km/h")
            }
        }
    }
}
