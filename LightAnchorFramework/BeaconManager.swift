//
//  BeaconManager.swift
//  LightAnchorFramework
//
//  Created by Nick Wilkerson on 9/30/19.
//  Copyright © 2019 Wiselab. All rights reserved.
//

import UIKit

public struct Beacon {
    var id: Int
    var code: Int
    var x: Int
    var y: Int
    var z: Int
}

public class BeaconManager: NSObject {

    public var beaconsIdDict = Dictionary<Int, Beacon>()
    
    let baseAtlasURL = URL(string: "https://xr.andrew.cmu.edu/beacon/local/")!
    
    func updateBeacons(with id: Int) {
        if beaconsIdDict.keys.contains(id) {
            return
        }
        requestBeaconData(with: id)
    }
    
    private func requestBeaconData(with id: Int) {
        let session = URLSession.shared
        let idString = String(format: "%d", id)
        let url = baseAtlasURL.appendingPathComponent(idString)
        let task = session.dataTask(with: url) { (data, response, error) in
            if let data = data {
                
                if let dataString = String(bytes: data, encoding: .utf8) {
                    NSLog("data string: \(dataString)")
                } else {
                    NSLog("data can't be stringified")
                }
                do {
                    var newBeaconsIdDict = [Int: Beacon]()
                    let jBeaconArray = try JSONSerialization.jsonObject(with: data, options: .init())
                    for jBeacon in jBeaconArray as! [Dictionary<String, Any>] {
                        let id = jBeacon["id"] as! Int
                        let code = jBeacon["code"] as! Int
                        let jLocationDict = jBeacon["location"] as! Dictionary<String, Int>
                        let x = jLocationDict["x"] as! Int
                        let y = jLocationDict["y"] as! Int
                        let z = jLocationDict["z"] as! Int
                        let beacon = Beacon(id: id, code: code, x: x, y: y, z: z)
                        newBeaconsIdDict[id] = beacon
                    }
                    self.beaconsIdDict = newBeaconsIdDict
                } catch {
                    print(error)
                }
                
                
            } else {
                NSLog("no data")
            }
            
        }
        task.resume()
    }
    
}
