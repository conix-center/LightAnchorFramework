//
//  LightAnchorPoseManager.swift
//  LightAnchors
//
//  Created by Nick Wilkerson on 7/29/19.
//  Copyright © 2019 Wiselab. All rights reserved.
//

import UIKit
import ARKit

public let kLightData = "LightData"


@objc public protocol LightAnchorPoseManagerDelegate {
    /* this delegate method must be implemented in order to correct ARKit's transform */
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdate transform: SCNMatrix4)
    /* this delegate method is used to display the centroids of detected clusters */
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdatePointsFor codeIndex: Int, displayMeanX:Float, displayMeanY: Float, displayStdDevX: Float, displayStdDevY: Float)
    /* this delegate method returns an image representing the detected pixels after all filtering */
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
    
    var frameCount = 0
    
    @objc public init(imageWidth:Int, imageHeight: Int, anchorLocations: [SCNVector3]) {
        super.init()
        NSLog("LightAnchorPoseManager init")

        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        
        self.anchorLocations = anchorLocations
        
        lightAnchorBleManager.delegate = self
        lightAnchorBleManager.scanForLightAnchors()
        
        lightDecoder.initializeMetal(width: imageWidth, height: imageHeight)
        lightDecoder.delegate = self
        
        let timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        


    }
    
    @objc func fireTimer() {
        print("timer fired")
        NSLog("\(self.frameCount) FPS")
        self.frameCount = 0
    }
    
    @objc public func process(frame: ARFrame) {
        
        cameraIntrinsics = frame.camera.intrinsics
        cameraTransform = frame.camera.transform
        
        if capturing == true {
            processPixelBuffer(frame.capturedImage)
        }
        
    }
    
    
    func processPixelBuffer(_ buffer: CVPixelBuffer) {
        
        frameCount += 1

        var grayPlaneIndex = -1
        let planeCount = CVPixelBufferGetPlaneCount(buffer)
    //    NSLog("target width: \(imageWidth), height: \(imageHeight)")
        for planeIndex in 0..<planeCount {
            let planeHeight = CVPixelBufferGetHeightOfPlane(buffer, planeIndex)
            let planeWidth = CVPixelBufferGetWidthOfPlane(buffer, planeIndex)
           // NSLog("plane width: \(planeWidth), plane height: \(planeHeight)")
            if planeWidth == imageWidth/*grayPlaneWidth*/ && planeHeight == imageHeight {
              //  NSLog("found gray plane with width: \(planeWidth) height: \(planeHeight)")
                grayPlaneIndex = planeIndex
            }
        }
        if grayPlaneIndex == -1 {
            NSLog("no gray plane found")
        }
        assert(grayPlaneIndex != -1)
        
        let numGrayBytes = imageWidth * imageHeight
    //    NSLog("numGrayBytes: \(numGrayBytes)")
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        
        if let baseAddressGray = CVPixelBufferGetBaseAddressOfPlane(buffer, grayPlaneIndex) {
            self.lightDecoder.decode(imageBytes: baseAddressGray, length: numGrayBytes)
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        
    }
    
    
    @objc public func startCapture() {
        capturing = true
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { (timer) in
            var dataValue = 0
                dataValue = UserDefaults.standard.integer(forKey: kLightData)
            self.lightDecoder.shouldSave = true
            self.lightAnchorBleManager.startBlinking(with: dataValue)
        }
    }
            
        
    @objc public func stopCapture() {
        capturing = false
        lightAnchorBleManager.stopBlinking()
        
        if let timer = blinkTimer {
            timer.invalidate()
        }
        capturing = false
        lightDecoder.evaluateResults()
    }
    
    
    
    
}


extension LightAnchorPoseManager: LightDecoderDelegate {
    func lightDecoder(_: LightDecoder, didUpdateResultImage resultImage: UIImage) {
        if let delegate = self.delegate {
            DispatchQueue.main.async {
                delegate.lightAnchorPoseManager(self, didUpdateResultImage: resultImage)
            }
        }
    }
    
    func lightDecoder(_: LightDecoder, didUpdate detectedPoints: [LightDecoderDetectedPoint]) {
        var anchorPoints = [AnchorPoint]()
        
        for detectedPoint in detectedPoints {
            let codeIndex = detectedPoint.codeIndex
            let imageMeanX = detectedPoint.meanX
            let imageMeanY = detectedPoint.meanY
            let imageStdDevX = detectedPoint.stdDevX
            let imageStdDevY = detectedPoint.stdDevY
            
            NSLog("imageMeanX: \(imageMeanX), imageMeanY: \(imageMeanY)")
            
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
            }
        }

        
        if anchorPoints.count >= 3 {
            
            let ct = simd_double4x4(cameraTransform)
            let ci = simd_double3x3(cameraIntrinsics)
            
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
