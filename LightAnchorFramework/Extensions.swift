//
//  Extensions.swift
//  LightAnchors
//
//  Created by Nick Wilkerson on 7/29/19.
//  Copyright © 2019 Wiselab. All rights reserved.
//

import UIKit
import ARKit

extension simd_float4x4 {
    init(_ m: simd_double4x4) {
        self.init()
        self.columns.0.x = Float(m.columns.0.x)
        self.columns.0.y = Float(m.columns.0.y)
        self.columns.0.z = Float(m.columns.0.z)
        self.columns.0.w = Float(m.columns.0.w)
        self.columns.1.x = Float(m.columns.1.x)
        self.columns.1.y = Float(m.columns.1.y)
        self.columns.1.z = Float(m.columns.1.z)
        self.columns.1.w = Float(m.columns.1.w)
        self.columns.2.x = Float(m.columns.2.x)
        self.columns.2.y = Float(m.columns.2.y)
        self.columns.2.z = Float(m.columns.2.z)
        self.columns.2.w = Float(m.columns.2.w)
        self.columns.3.x = Float(m.columns.3.x)
        self.columns.3.y = Float(m.columns.3.y)
        self.columns.3.z = Float(m.columns.3.z)
        self.columns.3.w = Float(m.columns.3.w)
    }
}


extension simd_float3x3 {
    init(_ m: simd_double3x3) {
        self.init()
        self.columns.0.x = Float(m.columns.0.x)
        self.columns.0.y = Float(m.columns.0.y)
        self.columns.0.z = Float(m.columns.0.z)
        self.columns.1.x = Float(m.columns.1.x)
        self.columns.1.y = Float(m.columns.1.y)
        self.columns.1.z = Float(m.columns.1.z)
        self.columns.2.x = Float(m.columns.2.x)
        self.columns.2.y = Float(m.columns.2.y)
        self.columns.2.z = Float(m.columns.2.z)
    }
}

extension simd_double4x4 {
    init(_ m: simd_float4x4) {
        self.init()
        self.columns.0.x = Double(m.columns.0.x)
        self.columns.0.y = Double(m.columns.0.y)
        self.columns.0.z = Double(m.columns.0.z)
        self.columns.0.w = Double(m.columns.0.w)
        self.columns.1.x = Double(m.columns.1.x)
        self.columns.1.y = Double(m.columns.1.y)
        self.columns.1.z = Double(m.columns.1.z)
        self.columns.1.w = Double(m.columns.1.w)
        self.columns.2.x = Double(m.columns.2.x)
        self.columns.2.y = Double(m.columns.2.y)
        self.columns.2.z = Double(m.columns.2.z)
        self.columns.2.w = Double(m.columns.2.w)
        self.columns.3.x = Double(m.columns.3.x)
        self.columns.3.y = Double(m.columns.3.y)
        self.columns.3.z = Double(m.columns.3.z)
        self.columns.3.w = Double(m.columns.3.w)
    }
}


extension simd_double3x3 {
    init(_ m: simd_float3x3) {
        self.init()
        self.columns.0.x = Double(m.columns.0.x)
        self.columns.0.y = Double(m.columns.0.y)
        self.columns.0.z = Double(m.columns.0.z)
        self.columns.1.x = Double(m.columns.1.x)
        self.columns.1.y = Double(m.columns.1.y)
        self.columns.1.z = Double(m.columns.1.z)
        self.columns.2.x = Double(m.columns.2.x)
        self.columns.2.y = Double(m.columns.2.y)
        self.columns.2.z = Double(m.columns.2.z)
    }
}
