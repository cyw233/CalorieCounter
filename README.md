# CalorieCounter
This application is a part of the software development project at The University of Mebourne. 
It can recognise 101 food types and measure distance between two points. By measure three dimensional
sizes of the food, the volume can be estimated and so as calorie intake. 

# Run
* Requirements: iOS 11.3, Xcode 9.3 and ARKit 1.5.

In a terminal:

1. sudo gem install cocoapods

2. cd CalorieCounter

3. pod install

4. double click on the .xcworkspace file (this is important, not the project file!)

5. click run in xcode



An external component "LBTAComponents" is needed. To install it, simply add the following line to your Podfile:

pod "LBTAComponents"

After installing "LBTAComponents", reopen the .xcworkspace file.

# Reference
* Apple 2017 , "Get Started witth ARKit", https://developer.apple.com/arkit/.
* LBTA components, https://github.com/bhlvoong/LBTAComponents.
