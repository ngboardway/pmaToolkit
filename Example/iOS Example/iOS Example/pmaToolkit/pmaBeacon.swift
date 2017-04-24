//
//  pmaBeacon.swift
//  pmaToolkit
//
//  Created by Peter.Alt on 2/24/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import UIKit
import CoreLocation

open class pmaBeacon: NSObject, NSCopying {
    
    open var alias : String?
    open var major : Int!
    open var minor : Int!

    open var originalBeacon: CLBeacon!
    open var lastSeen : Date?
    
    override init() {
        super.init()
    }
    
    init(alias: String?, major: Int, minor: Int, originalBeacon : CLBeacon?) {
        self.alias = alias
        self.major = major
        self.minor = minor
        self.originalBeacon = originalBeacon
    }
    
    open func copy(with zone: NSZone?) -> Any {
        let copy = pmaBeacon(alias: self.alias, major: self.major, minor: self.minor, originalBeacon: self.originalBeacon)
        return copy
    }
    
}
