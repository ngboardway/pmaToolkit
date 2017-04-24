//
//  pmaLocation.swift
//  pmaToolkit
//
//  Created by Peter.Alt on 2/24/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import UIKit

open class pmaLocation: NSObject {
    
    // Mark: Public var
    
    open var name : String!
    open var enabled = true
    open var floor : floors!
    open var type = types.gallery
    open var title : String?
    
    public enum types {
        case gallery
        case bathroom
        case stairs
        case elevator
        case food
        case store
        case info
    }
    
    public enum floors {
        case ground
        case first
        case second
    }
    
    
    open var objects = [pmaObject]()
    open var beacons = [pmaBeacon]()
    
    // Mark: Public
    
    open func respondsToBeacon(_ beacon: pmaBeacon) -> Bool {
        for b in self.beacons {
            if b.major == beacon.major && b.minor == beacon.minor {
                return true
            }
        }
        return false
    }
    
    open func isObjectAtLocation(_ object: pmaObject) -> Bool {
        for obj in self.objects {
            if obj.objectID == object.objectID {
                return true
            }
        }
        return false
    }
    
}
