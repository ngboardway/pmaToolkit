//
//  pmaBeacon.swift
//  pmaToolkit
//
//  Created by Peter.Alt on 2/24/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import UIKit
import CoreLocation

public class pmaBeacon: NSObject, NSCopying {
    
    public var alias : String?
    public var major : Int!
    public var minor : Int!

    public var originalBeacon: CLBeacon!
    public var lastSeen : NSDate?
    
    override init() {
        super.init()
    }
    
    init(alias: String?, major: Int, minor: Int, originalBeacon : CLBeacon?) {
        self.alias = alias
        self.major = major
        self.minor = minor
        self.originalBeacon = originalBeacon
    }
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = pmaBeacon(alias: self.alias, major: self.major, minor: self.minor, originalBeacon: self.originalBeacon)
        return copy
    }
    
}
