# LightAnchorFramework

To build the light anchor framework

1.  Clone this repository
2.  Install Cocoapods using "sudo gem install cocoapods"
3.  Run "pod install" in the directory of this repository
4.  Open the .xcworkspace file
5.  Build the project by clicking the play button


To use the light anchor framework 
1.  Copy the framework file from products into a new project
2.  build the .metallib file by running:
    xcrun -sdk iphoneos metal -c lightanchorkernels.metal -o lightanchorkernels.air
    xcrun -sdk iphoneos metallib lightanchorkernels.air -o lightanchorkernels.metallib
3.  Copy the .metallib file into the new project
