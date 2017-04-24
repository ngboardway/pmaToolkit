//
//  pmaLocation.swift
//  pmaToolkit
//
//  Created by Peter.Alt on 2/24/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import UIKit

public class pmaLocation: NSObject {
    
    // Mark: Public var
    
    public var name : String!
    public var enabled = true
    public var floor : floors!
    public var type = types.gallery
    public var title : String?
    
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
    
    
    public var objects = [pmaObject]()
    public var beacons = [pmaBeacon]()
    
    // Mark: Public
    
    public func respondsToBeacon(beacon: pmaBeacon) -> Bool {
        for b in self.beacons {
            if b.major == beacon.major && b.minor == beacon.minor {
                return true
            }
        }
        return false
    }
    
    public func isObjectAtLocation(object: pmaObject) -> Bool {
        for obj in self.objects {
            if obj.objectID == object.objectID {
                return true
            }
        }
        return false
    }
    
}
