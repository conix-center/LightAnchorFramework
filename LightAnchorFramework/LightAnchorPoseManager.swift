//
//  LightAnchorPoseManager.swift
//  LightAnchors
//
//  Created by Nick Wilkerson on 7/29/19.
//  Copyright © 2019 Wiselab. All rights reserved.
//

import UIKit
import ARKit

//public struct ImageSize {
//    var width: Int
//    var height: Int
//}

public let kLightData = "LightData"



//let anchor1Location = SCNVector3(0,0,0)
//let anchor2Location = SCNVector3(0,3.084,0)
//let anchor3Location = SCNVector3(3.084,3.084,0)
//let anchor4Location = SCNVector3(3.084,0,0)


@objc public protocol LightAnchorPoseManagerDelegate {
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdate transform: SCNMatrix4)
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdatePointsFor codeIndex: Int, displayMeanX:Float, displayMeanY: Float, displayStdDevX: Float, displayStdDevY: Float)
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdateResultImage resultImage: UIImage)
}

@objc public class LightAnchorPoseManager: NSObject {
    
    /* delegate */
    @objc public var delegate: LightAnchorPoseManagerDelegate?
    
    /* encapsulated classes */
    let lightDecoder = LightDecoder()
    let poseSolver = PoseSolver()
    let lightAnchorBleManager = LightAnchorBleManager()
    
    var blinkTimer: Timer?
    
    /* state */
    @objc public var capturing = false
    
    /* permanent data */
    //@objc public var imageSize = ImageSize(width: 0, height: 0)
    @objc public var imageWidth = 0
    @objc public var imageHeight = 0
    @objc public var anchorLocations = [SCNVector3]()
    
    /* temporary data */
    var cameraIntrinsics = simd_float3x3()
    var cameraTransform = simd_float4x4()
    
    @objc public init(imageWidth:Int, imageHeight: Int, anchorLocations: [SCNVector3]) {
        super.init()
        //imageSize.width = imageWidth
        //imageSize.height = imageHeight
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        
        self.anchorLocations = anchorLocations
        
        lightAnchorBleManager.delegate = self
        lightAnchorBleManager.scanForLightAnchors()
        
        lightDecoder.initializeMetal(width: imageWidth, height: imageHeight)
        lightDecoder.delegate = self
    }
    
    @objc public func process(frame: ARFrame) {
        
        cameraIntrinsics = frame.camera.intrinsics
        cameraTransform = frame.camera.transform
        
        if capturing == true {
            processPixelBuffer(frame.capturedImage)
        }
        
    }
    
    
    func processPixelBuffer(_ buffer: CVPixelBuffer) {
        //        let now = Date()
        //        let dateString = fileNameDateFormatter.string(from: now)
        //        let fileName = String(format: "%@.gray", dateString)
        
        //       let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        //       if let filePath = paths.first?.appendingPathComponent(fileName) {
        //            let format = CVPixelBufferGetPixelFormatType(buffer)
        //            let width = CVPixelBufferGetWidth(buffer)
        //            let height = CVPixelBufferGetHeight(buffer)
        //            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        //            NSLog("pixelBuffer width: %d, height: %d, format: \(format), bytes per row: \(bytesPerRow) ", width, height)
        
        //            let grayPlaneHeight = 1920
        //            let grayPlaneWidth = 1440
        var grayPlaneIndex = 0
        let planeCount = CVPixelBufferGetPlaneCount(buffer)
        for planeIndex in 0..<planeCount {
            let planeHeight = CVPixelBufferGetHeightOfPlane(buffer, planeIndex)
            let planeWidth = CVPixelBufferGetWidthOfPlane(buffer, planeIndex)
            if planeWidth == imageWidth/*grayPlaneWidth*/ && planeHeight == imageHeight/*grayPlaneHeight*/ {
                NSLog("found gray plane")
                grayPlaneIndex = planeIndex
            }
        }
        
        let numGrayBytes = imageWidth * imageHeight//grayPlaneHeight*grayPlaneWidth
        NSLog("numGrayBytes: \(numGrayBytes)")
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        
        if let baseAddressGray = CVPixelBufferGetBaseAddressOfPlane(buffer, grayPlaneIndex) {
            self.lightDecoder.decode(imageBytes: baseAddressGray, length: numGrayBytes)
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        //     }
        
    }
    
    
    @objc public func toggleCapture() {
        if capturing == false { // start
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { (timer) in
                //           NSLog("Fire!")
                var dataValue = 0
//                if UserDefaults.standard.bool(forKey: kGenerateRandomData) {
//                    dataValue = Int.random(in: 0..<0x3F)
//                } else {
                    dataValue = UserDefaults.standard.integer(forKey: kLightData)
 //               }
                self.lightDecoder.shouldSave = true
                //          NSLog("set data to: %@", dataString)
                //         self.lightDataLabel.text = dataString
                self.lightAnchorBleManager.startBlinking(with: dataValue)
            }
            
            capturing = true
        } else { // stop
            lightAnchorBleManager.stopBlinking()
            
            if let timer = blinkTimer {
                timer.invalidate()
            }
            capturing = false
            lightDecoder.evaluateResults()
        }
    }
    
    
    
    
}


extension LightAnchorPoseManager: LightDecoderDelegate {
    func lightDecoder(_: LightDecoder, didUpdateResultImage resultImage: UIImage) {
        //      NSLog("received result image")
        //imageView.image = resultImage
        if let delegate = self.delegate {
            DispatchQueue.main.async {
                delegate.lightAnchorPoseManager(self, didUpdateResultImage: resultImage)
            }
        }
    }
    
    func lightDecoder(_: LightDecoder, didUpdate detectedPoints: [LightDecoderDetectedPoint]) {
        
//        var point1: CGPoint?
//        var point2: CGPoint?
//        var point3: CGPoint?
//        var point4: CGPoint?
        
        var anchorPoints = [AnchorPoint]()
        
        for detectedPoint in detectedPoints {
            let codeIndex = detectedPoint.codeIndex
            let imageMeanX = detectedPoint.meanX
            let imageMeanY = detectedPoint.meanY
            let imageStdDevX = detectedPoint.stdDevX
            let imageStdDevY = detectedPoint.stdDevY
            
            let avgStdDev = CGFloat((imageStdDevX + imageStdDevY) / 2.0)
            
            var displayMeanX = Float(0.0)
            var displayMeanY = Float(0.0)
            var displayStdDevX = Float(0.0)
            var displayStdDevY = Float(0.0)
            
            if UIDevice.current.orientation == .portrait || UIDevice.current.orientation == .portraitUpsideDown {
                (displayMeanX, displayMeanY, displayStdDevX, displayStdDevY) = lightDecoder.rotateToPortrait(initialWidth: Float(UIScreen.main.bounds.size.width), initialHeight: Float(UIScreen.main.bounds.size.height), meanX: imageMeanX, meanY: imageMeanY, stdDevX: imageStdDevX, stdDevY: imageStdDevY)
            } else {
                (displayMeanX, displayMeanY, displayStdDevX, displayStdDevY) = (imageMeanX, imageMeanY, imageStdDevX, imageStdDevY)
            }
            
            if let delegate = self.delegate {
                DispatchQueue.main.async {
                    delegate.lightAnchorPoseManager(self, didUpdatePointsFor: codeIndex, displayMeanX: displayMeanX, displayMeanY: displayMeanY, displayStdDevX: displayStdDevX, displayStdDevY: displayStdDevY)
                }
            }
            
            if avgStdDev > 150 {
                
            } else {
                if codeIndex-1 < anchorLocations.count {
                    anchorPoints.append(AnchorPoint(location3d: anchorLocations[codeIndex-1], location2d: CGPoint(x: CGFloat(imageMeanX), y: CGFloat(imageMeanY))))
                }
//                if codeIndex == 1 {
//                    point1 = CGPoint(x: CGFloat(imageMeanX), y: CGFloat(imageMeanY))
//                } else if codeIndex == 2 {
//                    point2 = CGPoint(x: CGFloat(imageMeanX), y: CGFloat(imageMeanY))
//
//                } else if codeIndex == 3 {
//                    point3 = CGPoint(x: CGFloat(imageMeanX), y: CGFloat(imageMeanY))
//                } else if codeIndex == 4 {
//                    point4 = CGPoint(x: CGFloat(imageMeanX), y: CGFloat(imageMeanY))
//                }
            }
        }
        
        
        
//        if
//        if let p1=point1 {
//            anchorPoints.append(AnchorPoint(location3d: anchor1Location, location2d: p1))
//        }
//        if let p2=point2 {
//            anchorPoints.append(AnchorPoint(location3d: anchor2Location, location2d: p2))
//        }
//        if let p3=point3 {
//            anchorPoints.append(AnchorPoint(location3d: anchor3Location, location2d: p3))
//        }
//        if let p4=point4 {
//            anchorPoints.append(AnchorPoint(location3d: anchor4Location, location2d: p4))
//        }
        
        if anchorPoints.count >= 3 {
            
            let ct = simd_double4x4(cameraTransform)
            let ci = simd_double3x3(cameraIntrinsics)
            
            //            let anchorPoints = [AnchorPoint(location3d: anchor1Location,
            //                                            location2d: CGPoint(x: 480.689730834961, y: 396.2117563883463)),
            //                                AnchorPoint(location3d: anchor2Location,
            //                                            location2d: CGPoint(x: 484.14217783610025, y: 141.3753122965494)),
            //                                AnchorPoint(location3d: anchor3Location,
            //                                            location2d: CGPoint(x: 954.0138305664062, y: 140.217827351888)),
            //                                AnchorPoint(location3d: anchor4Location,
            //                                            location2d: CGPoint(x: 848.7600453694662, y: 423.5507278442383))]
            //
            //            let ct = simd_double4x4(simd_double4(0.005047297570854425, -0.9977597594261169, 0.06670882552862167, 0.0),
            //                                    simd_double4(0.9994179010391235, 0.00278222793713212, -0.03400397300720215, 0.0),
            //                                    simd_double4(0.03374219685792923, 0.06684162467718124, 0.9971930384635925, 0.0),
            //                                    simd_double4(0.002935945987701416, -0.0066966712474823, 0.012121886946260929, 1.0))
            //
            //            let ci = simd_double3x3(columns: (simd_double3(1015.6875610351562, 0.0, 0.0),
            //                                              simd_double3(0.0, 1015.6875610351562, 0.0),
            //                                              simd_double3(639.5, 359.5, 1.0)))
            
            poseSolver.solveForPose(intrinsics: ci, cameraTransform: ct, anchorPoints: anchorPoints) { (transform, success) in
                NSLog("transform success: %@", success ? "true" : "false")
                var validTransform = true
                for i in 0..<4 {
                    if transform.columns.0[i].isNaN || transform.columns.1[i].isNaN || transform.columns.2[i].isNaN || transform.columns.3[i].isNaN {
                        validTransform = false
                    }
                    print(String(transform.columns.0[i]) + "\t\t" + String(transform.columns.1[i]) + "\t\t" + String(transform.columns.2[i]) + "\t\t" + String(transform.columns.3[i]))
                }
                if validTransform {
                    NSLog("valid")
                    if let delegate = self.delegate {
                        let transform = SCNMatrix4.init(transform)
                        DispatchQueue.main.async {
                            delegate.lightAnchorPoseManager(self, didUpdate: transform)
                        }
                    }
                    
                }
            }
            
        }
        
    }
    
    
}



extension LightAnchorPoseManager: LightAnchorBleManagerDelegate {
    func lightAnchorManager(bleManager: LightAnchorBleManager, didDiscoverLightAnchorIdentifiedBy lightAnchorId: Int) {
        // numConnectionsLabel.text = String(format: "# Connections: %d", lightAnchorManager.lightAnchors.count)
    }
    
    func lightAnchorManagerDidDisconnectFromLightAnchor(bleManager: LightAnchorBleManager) {
        
    }
    
    
}
