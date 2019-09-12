# LightAnchorFramework

To build the light anchor framework

1. Install XCode from the App Store
1. Clone this repository
1. Open the .xcodeproj file
1. Plug in an iOS device
1. Select the iOS device from the drop down next to the target at the top of XCode
1. Build the project by clicking the play button in xcode

To build the metallib file

1. Navigate to the folder containing the .metal file
1. Run

    xcrun -sdk iphoneos metal -c lightanchorkernels.metal -o lightanchorkernels.air
    
    xcrun -sdk iphoneos metallib lightanchorkernels.air -o lightanchorkernels.metallib


To use the light anchor framework in a new project

1. Install cocoapods by running "sudo gem install cocoapods" in the terminal
1. Create a new xcode project
1. Quit the xcode project
1. Navigate in a terminal to the project folder
1. Run "pod init"
1. Add 'pod "LASwift"' after the first target line in the "podfile" that was created when "pod init" was run
1. Run "pod install"
1. Open the white .xcworkspace file (not the blue .xcodeproj file)
1. Copy the framework file from products into a new project    
1. Copy the .metallib file into the new project
1. Within xcode drag the framework from the left side into "Embedded Binaries" in the general tab of your target's settings
1. Plug in an iOS device
1. Select the iOS device from the drop down next to the target at the top of XCode
1. Click the play button

Create an instance of LightAnchorPoseManager
Set a class to be the delegate of LightAnchorPoseManager
Implement the LightAnchorPoseManagerDelegate methods 
```
@objc public protocol LightAnchorPoseManagerDelegate {
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdate transform: SCNMatrix4)
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdatePointsFor codeIndex: Int, displayMeanX:Float, displayMeanY: Float, displayStdDevX: Float, displayStdDevY: Float)
    func lightAnchorPoseManager(_ :LightAnchorPoseManager, didUpdateResultImage resultImage: UIImage)
}
```
