//
//  LightAnchorManager.swift
//  BlinkRecorder
//
//  Created by Nick Wilkerson on 2/4/19.
//  Copyright © 2019 Wiselab. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol LightAnchorBleManagerDelegate {
    func lightAnchorManager(bleManager: LightAnchorBleManager, didDiscoverLightAnchorIdentifiedBy lightAnchorId: Int)
    func lightAnchorManagerDidDisconnectFromLightAnchor(bleManager: LightAnchorBleManager)
}

class LightAnchorBleManager: NSObject {
    
    var delegate: LightAnchorBleManagerDelegate?
    
    /* bluetooth */
    var bleManager:CBCentralManager?
    var lightAnchors = [CBPeripheral]()
    let lightTriggerServiceUUID =        CBUUID(string: "F0001180-0451-4000-B000-000000000000")
    let lightTriggerCharacteristicUUID = CBUUID(string: "F0001112-0451-4000-B000-000000000000")
    let lightIdServiceUUID             = CBUUID(string: "F0001170-0451-4000-B000-000000000000")
    let lightIdCharacteristicUUID      = CBUUID(string: "F0001111-0451-4000-B000-000000000000")
    
    
    
    override init() {
        super.init()
        self.bleManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scanForLightAnchors() {
        if let bleManager = self.bleManager {
            bleManager.scanForPeripherals(withServices: nil)
        }
    }
    
    
    func startBlinking(with dataValue: Int) {
        for lightAnchor in lightAnchors {
            if let services = lightAnchor.services {
                for service in services {
                    if let characteristics = service.characteristics {
                        for characteristic in characteristics {
                            if characteristic.uuid == lightTriggerCharacteristicUUID {
                                var value:UInt8 = 0x1
                                let data = Data(bytes:&value, count: MemoryLayout.size(ofValue: value))
                                characteristic.service.peripheral.writeValue(data, for: characteristic, type: .withResponse)
                            } else if characteristic.uuid == lightIdCharacteristicUUID {
                                //let dataValue = UserDefaults.standard.integer(forKey: kLightData)
                                var value: UInt8 = UInt8(dataValue)//0x2A
                                let data = Data(bytes:&value, count: MemoryLayout.size(ofValue: value))
                                characteristic.service.peripheral.writeValue(data, for: characteristic, type: .withResponse)
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func stopBlinking() {
        for lightAnchor in lightAnchors {
            if let services = lightAnchor.services {
                for service in services {
                    if let characteristics = service.characteristics {
                        for characteristic in characteristics {
                            if characteristic.uuid == lightTriggerCharacteristicUUID {
                                var value:UInt8 = 0x0
                                let data = Data(bytes:&value, count: MemoryLayout.size(ofValue: value))
                                characteristic.service.peripheral.writeValue(data, for: characteristic, type: .withResponse)
                                //lightDataLabel.text = ""
                            }
                        }
                    }
                }
            }
        }
    }
    
    
}


extension LightAnchorBleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .poweredOn:
            bleManager?.scanForPeripherals(withServices: nil)
        case .unknown:
            break
        case .resetting:
            break
        case .unsupported:
            break
        case .unauthorized:
            break
        case .poweredOff:
            break
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //        NSLog("did discover peripheral: %@", peripheral.name ?? "")
        
        if let pName = peripheral.name {
            if pName == "LightAnchor" || pName == "Light Anchor" {
                NSLog("Found a Light Anchor")
                for key in advertisementData.keys {
                    NSLog("key: \(key)")
                    if key == "kCBAdvDataManufacturerData" {
                        NSLog("found manufacturer data")
                        let mData = advertisementData[key]
                        NSLog("mData: \(mData)")
                        let d = mData as! Data
                        NSLog("d: \(d)")
                        NSLog("d[0]: \(d[0])")
                        var id = 0
                        for i in stride(from: 5, through: 2, by: -1) {
                            id *= 255
                            id += Int(d[i])
                        }
                        NSLog("id: \(id)")
                        
                    }
                }
                lightAnchors.append(peripheral)
                
                self.delegate?.lightAnchorManager(bleManager: self, didDiscoverLightAnchorIdentifiedBy: 0)
                bleManager?.connect(peripheral, options: nil)
            }
        }
        
    }
    
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("did fail to connect to: \(peripheral.name ?? "no name")")
        //        let alertController = UIAlertController(title: "Failed to Connect", message: "Failed to Connect to \(peripheral.name ?? "no name")", preferredStyle: .alert)
        //        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        //        alertController.addAction(okAction)
        //        self.present(alertController, animated: true) {
        //
        //        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("did disconnect from: \(peripheral.name ?? "no name")")
        //       self.navigationController?.popToRootViewController(animated: true)
        //        let alertController = UIAlertController(title: "Lost Connection", message: "Lost Connection to \(peripheral.name ?? "no name")", preferredStyle: .alert)
        //        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        //        alertController.addAction(okAction)
        //        self.present(alertController, animated: true, completion: nil)
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral.name == "LightAnchor" || peripheral.name == "Light Anchor" {
            NSLog("didConnect to light anchor")
            peripheral.delegate = self
            peripheral.discoverServices([lightIdServiceUUID, lightTriggerServiceUUID])
        }
    }
    
    
    
    
    
}



extension LightAnchorBleManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        NSLog("didDiscoverServices")
        if let services = peripheral.services {
            for service in services {
                NSLog("    %@", service.uuid.uuidString)
                service.peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        NSLog("didDiscoverCharacteristics")
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value {
            NSLog("wrote value: %@ for characteristic: %@",  value.hexEncodedString(), characteristic.uuid.uuidString)
        } else {
            //       NSLog("characteristic has no value")
        }
        if let err = error {
            NSLog("error writing to characteristic: %@", err.localizedDescription)
            //            if let dict = dataPointDict {
            //                dict.setValue(true, forKey: "error")
            //            }
        }
    }
}




extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}
