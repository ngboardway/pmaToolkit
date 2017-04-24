//
//  ViewController.swift
//  iOS Example
//
//  Created by Peter.Alt on 3/9/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import UIKit
import pmaToolkit

class ViewController: UIViewController {
    
    let locationManager = pmaLocationManager()
    
    @IBOutlet weak var currentLocationLabel: UILabel!
    @IBOutlet weak var currentHeadingLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.startUpdateHeading()
        locationManager.startRangingBeacons(.MainBuilding)
        
        pmaToolkit.registerNotification(self, function: "locationChanged:", type: "locationChanged")
        pmaToolkit.registerNotification(self, function: "locationUnknown:", type: "locationUnknown")
        
        pmaToolkit.registerNotification(self, function: "headingUpdated:", type: "didUpdateHeading")
        
        // This is optional and another way to keep checking if we currently know where we are inside the building
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("checkForCurrentLocation"), userInfo: nil, repeats: true)
        
    }
    
    func checkForCurrentLocation() {
        pmaToolkit.logInfo("Current location: \(self.locationManager.getCurrentLocation()?.name)")
    }
    
    func locationUnknown(notification: NSNotification) {
        if let location = pmaToolkit.getObjectFromNotificationForKey(notification, key: "lastKnownLocation") as? pmaLocation {
            self.currentLocationLabel.text = "Location unknown, last known location: \(location.name)"
        } else {
            self.currentLocationLabel.text = "Location unknown"
        }
    }
    
    func locationChanged(notification: NSNotification) {
        if let location = pmaToolkit.getObjectFromNotificationForKey(notification, key: "currentLocation") as? pmaLocation {
            self.currentLocationLabel.text = "Location: \(location.name)"
        }
    }
    
    func headingUpdated(notification: NSNotification) {
        if let heading = pmaToolkit.getObjectFromNotificationForKey(notification, key: "calculatedHeadingRadians") as? CGFloat {
            self.currentHeadingLabel.text = "Heading: \(heading)"
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

