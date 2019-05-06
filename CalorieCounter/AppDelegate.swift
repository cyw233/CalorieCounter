//
//  AppDelegate.swift
//
//  Created by Sheng Wu on 01/05/2018.
//  Copyright © 2018 Sheng Wu. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
//    window = UIWindow()
//    window?.makeKeyAndVisible()
//
//    let gameViewController = GameViewController()
//    window?.rootViewController = gameViewController
//    UIApplication.shared.isIdleTimerDisabled = true
    UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
    // Sets shadow (line below the bar) to a blank image
    UINavigationBar.appearance().shadowImage = UIImage()
    // Sets the translucent background color
    UINavigationBar.appearance().backgroundColor = .clear
    // Set translucent. (Default value is already true, so this can be removed if desired.)
    UINavigationBar.appearance().isTranslucent = true
    
    return true
  }
 

}

