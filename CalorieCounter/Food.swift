//
//  Food.swift
//  Calories
//
//  Created by Sheng Wu on 23/4/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit
import os.log

class Food {
    //MARK: Properties
    var type: String
    var calories: Double
    
    //MARK: Types
    struct PropertyKey {
        static let type = "type"
        static let calories = "calories"
    }
    
    //MARK: Initialization
    init?(type: String, calories: Double) {
        // The name must not be empty
        guard !type.isEmpty else {
            return nil
        }
        // The calories must > 0
        guard (calories >= 0) else {
            return nil
        }
        // Initialization should fail if there is no name or if the rating is negative.
        if type.isEmpty || calories < 0  {
            return nil
        }
        // Initialize stored properties.
        self.type = type
        self.calories = calories
    }
}
