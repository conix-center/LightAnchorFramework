# LightAnchorFramework

To build the light anchor framework

1. Clone this repository
2. Install Cocoapods using "sudo gem install cocoapods"
3. Run "pod install" in the directory of this repository
4. Open the white .xcworkspace file (not the blue .xcodeproj file)
5. Build the project by clicking the play button

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
1. Add 'pod "LASwift"' to the target in the "podfile" that was created when "pod init" was run
1. Run "pod install"
1. Open the white .xcworkspace file (not the blue .xcodeproj file)
1. Copy the framework file from products into a new project    
1. Copy the .metallib file into the new project
1. Within xcode drag the framework from the left side into "Embedded Binaries" in the general tab of your target's settings
1. Click the play button

