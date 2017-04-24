//
//  pmaLocationManager.swift
//  pmaToolkit
//
//  Created by Peter.Alt on 2/24/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import SwiftyJSON
import CoreBluetooth
import MediaPlayer

public class pmaLocationManager : NSObject, CLLocationManagerDelegate {
    
    public enum locationSensingType : Int {
        case MainBuilding
    }
    
    public var objects = [pmaObject]()
    public var locations = [pmaLocation]()
    public var beacons = [pmaBeacon]()
    
    public var currentLocation : pmaLocation?
    public var previousLocation : pmaLocation?
    
    private let locationManager = CLLocationManager()
    
    private var beaconsInRange = [pmaBeacon]()
    private var locationsInRange = [[pmaLocation : Float]]()
    
    private var unknownLocationTimestamp = NSDate()
    private var sensingType : locationSensingType!
    
    // MARK: Init
    
    public override init() {
        super.init()
        self.locationManager.delegate = self
    }
    
    // MARK: Loading Remote Data
    
    private func loadBeacons(completionHandler: () -> ()) {
        pmaToolkit.logInfo("Loading beacons...")
        dispatch_async(pmaToolkit.serialLoadingQueue) {
            if let jsonData = pmaCacheManager.loadJSONFile(pmaToolkit.settings.cacheSettings.urlBeacons) {
                if jsonData != nil {
                    for (_, beaconValues): (String, JSON) in jsonData["beacons"] {
                        
                        let newBeacon = pmaBeacon()
                        
                        if let alias = beaconValues["alias"].string {
                            if alias != "" {
                                newBeacon.alias = alias
                            }
                        }
                        
                        if let major = beaconValues["major"].int {
                            newBeacon.major = major
                        }
                        
                        if let minor = beaconValues["minor"].int {
                            newBeacon.minor = minor
                        }
                        
                        self.beacons.append(newBeacon)
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler()
                for beacon in self.beacons {
                    
                    pmaToolkit.logDebug("Beacon loaded: \(beacon.alias) - Major: \(beacon.major), Minor: \(beacon.minor)")
                    
                    if let location = self.getLocationFromBeaconAlias(beacon.alias!) {
                        location.beacons.append(beacon)
                        pmaToolkit.logDebug("Adding beacon \(beacon.alias) to location \(location.name)")
                    }
                }
                
                pmaToolkit.logInfo("Beacons loaded: \(self.beacons.count)")
            }
        }
    }
    
    private func loadLocations(completionHandler: () -> ()) {
        pmaToolkit.logInfo("Loading locations...")
        dispatch_async(pmaToolkit.serialLoadingQueue) {
            if let jsonData = pmaCacheManager.loadJSONFile(pmaToolkit.settings.cacheSettings.urlLocations) {
                if jsonData != nil {
                    for (_, locationValues): (String, JSON) in jsonData["locations"] {
                        
                        let newLocation = pmaLocation()
                        
                        if let name = locationValues["name"].string {
                            if name != "" {
                                newLocation.name = name
                            }
                        }
                        
                        if let title = locationValues["title"].string {
                            if title != "" {
                                newLocation.title = title
                            }
                        }
                        
                        if let floor = locationValues["floor"].string {
                            if floor.lowercaseString == "ground" {
                                newLocation.floor = pmaLocation.floors.ground
                            } else if floor.lowercaseString == "first" {
                                newLocation.floor = pmaLocation.floors.first
                            } else if floor.lowercaseString == "second" {
                                newLocation.floor = pmaLocation.floors.second
                            }
                        }
                        
                        if let type = locationValues["type"].string {
                            if type.lowercaseString == "elevator" {
                                newLocation.type = pmaLocation.types.elevator
                            } else if type.lowercaseString == "food" {
                                newLocation.type = pmaLocation.types.food
                            } else if type.lowercaseString == "info" {
                                newLocation.type = pmaLocation.types.info
                            } else if type.lowercaseString == "stairs" {
                                newLocation.type = pmaLocation.types.stairs
                            } else if type.lowercaseString == "gallery" {
                                newLocation.type = pmaLocation.types.gallery
                            } else if type.lowercaseString == "store" {
                                newLocation.type = pmaLocation.types.store
                            } else if type.lowercaseString == "bathroom" {
                                newLocation.type = pmaLocation.types.bathroom
                            }
                        }
                        
                        if let enabled = locationValues["enabled"].bool {
                            newLocation.enabled = enabled
                        }
                        
                        self.locations.append(newLocation)
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler()
                for location in self.locations {
                    pmaToolkit.logDebug("Location loaded: \(location.name) - Floor \(location.floor), Type: \(location.type), Enabled: \(location.enabled), Title: \(location.title)")
                }
                pmaToolkit.logInfo("Locations loaded: \(self.locations.count)")
            }
        }
    }
    
    // MARK: Ranging Beacons

    public func startRangingBeacons(sensingType: locationSensingType) {
        if pmaToolkit.configurationIsValid() {
            self.loadLocations({
                self.loadBeacons({
                    self.sensingType = sensingType
                    self.startRangingBeaconsInRegion()
                })
            })
        } else {
            pmaToolkit.logError("No valid configuration provided for iBeacon and Location definitions.")
        }
        
    }
    
    private func startRangingBeaconsInRegion() {
        if self.areBeaconsLoaded() {
            if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedWhenInUse) {
                locationManager.requestWhenInUseAuthorization()
            }
            
            let region = CLBeaconRegion(proximityUUID: NSUUID(UUIDString: pmaToolkit.settings.iBeaconUUID)!, identifier: pmaToolkit.settings.iBeaconIdentifier)
            
            locationManager.startRangingBeaconsInRegion(region)
            locationManager.desiredAccuracy =  kCLLocationAccuracyBest
            
            if self.sensingType == locationSensingType.MainBuilding {
                NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("scanForMainBuildingBeaconsInRange"), userInfo: nil, repeats: true)
            }
            
        } else {
            pmaToolkit.logError("No beacon definitions loaded. Cannot start ranging beacons")
        }
    }
    
    public func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Entered Region
    }
    
    public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Exited Region
    }
    
    public func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        
        if self.sensingType == locationSensingType.MainBuilding {
            self.processBeaconsForMainBuilding(beacons)
        }
    }
    
    // MARK: Heading
    
    public func startUpdateHeading() {
        pmaToolkit.logInfo("Start updating heading information")
        locationManager.headingFilter = pmaToolkit.settings.headingFilter
        locationManager.startUpdatingHeading()
    }
    
    public func locationManager(manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        let angle_in_degrees : CGFloat = CGFloat(newHeading.magneticHeading)
        let angle_in_radians = ((180 - (angle_in_degrees + 135)) * 3.1415) / 180.0
        
        pmaToolkit.postNotification("didUpdateHeading", parameters: ["actualHeadingDegrees" : newHeading, "calculatedHeadingRadians" : angle_in_radians])
    }
    
    // MARK: Location Calculation
    
    private func addBeaconToBeaconsInRange(beacon: CLBeacon, proximity: CLProximity) {
        
        if let matched = self.getPMABeaconForCLBeacon(beacon) {
            let matchedBeacon = matched.copy() as! pmaBeacon
            matchedBeacon.originalBeacon = beacon
            matchedBeacon.lastSeen = NSDate()
            
            var proximityName = ""
            
            switch proximity {
            case CLProximity.Immediate :
                self.beaconsInRange.append(matchedBeacon)
                self.beaconsInRange.append(matchedBeacon)
                proximityName = "Immediate"
            case CLProximity.Near :
                self.beaconsInRange.append(matchedBeacon)
                proximityName = "Near"
            case CLProximity.Far :
                self.beaconsInRange.append(matchedBeacon)
                proximityName = "Far"
            default:
                pmaToolkit.logDebug("No beacon to append.")
            }
            
            pmaToolkit.logDebug("Adding to range: \(proximityName) - \(matchedBeacon.alias), ACC \(String(format: "%.2f", beacon.accuracy))m, RSSI \(beacon.rssi)dB, rangeCount: \(self.beaconsInRange.count)")
            
        }
    }
    
    func countOccurenceForBeaconsInRange() -> [pmaBeacon : Int] {
        var debugString = "Beacons in range: \(self.beaconsInRange.count) - "
        
        var countForEachBeacon = [pmaBeacon : Int]()
        
        for beacon in self.beaconsInRange {
            
            if countForEachBeacon.keys.contains(beacon) {
                countForEachBeacon[beacon]! += 1
            } else {
                // initializing the dictionary for that beacon
                countForEachBeacon[beacon] = 1
            }
        }
        
        for (beacon, count) in countForEachBeacon {
            debugString += "\(count)x \(beacon.alias)"
        }
        
        if !self.beaconsInRange.isEmpty && pmaToolkit.settings.beaconVerboseLogging {
            pmaToolkit.logDebug(debugString)
        }
        
        return countForEachBeacon
    }
    
    func calculateRelativeProbabilityDistributionForBeaconsInRange(ListOfBeaconsWithOccurenceCount: [pmaBeacon : Int]) ->  [pmaBeacon : Float] {
        var percentageForEachBeacon = [pmaBeacon : Float]()
        
        var debugString = "Probability per beacon: "
        
        for (beacon, count) in ListOfBeaconsWithOccurenceCount {
            
            percentageForEachBeacon[beacon] = Float(count) / Float(self.beaconsInRange.count)
            debugString += "\(beacon.alias): \(percentageForEachBeacon[beacon]!), "
        }
        
        if !ListOfBeaconsWithOccurenceCount.isEmpty && pmaToolkit.settings.beaconVerboseLogging {
            pmaToolkit.logDebug(debugString)
        }
        
        return percentageForEachBeacon
    }
    
    func calculateProbabilityForLocationsFromBeaconsInRange(probabilityForEachBeacon : [pmaBeacon : Float]) -> [pmaLocation : Float] {
        var locationPercentage = [pmaLocation : Float]()
        
        for location in self.locations {
            locationPercentage[location] = 0
        }
        
        for (beacon, percent) in probabilityForEachBeacon {
            
            if let locationFromBeacon = self.getLocationForBeacon(beacon) {
                // we got the location from the beacon
                locationPercentage[locationFromBeacon]! += percent
            }
        }
        
        for (location, percent) in locationPercentage {
            if percent == 0 {
                locationPercentage.removeValueForKey(location)
            }
        }
        
        return locationPercentage
    }
    
    func assumeCurrentLocation(probabilityForEachLocation: [pmaLocation : Float]) -> (location: pmaLocation, probability: Float)? {
        if self.areLocationsLoaded() {
        
            let maxPercentage = probabilityForEachLocation.values.maxElement()
            let maxLocation = pmaToolkit.allKeysForValueFromDictionary(probabilityForEachLocation, val: maxPercentage!).first
            
            return (location: maxLocation!, probability: maxPercentage!)
            
        }
        return nil
    }
    
    private func processBeaconsForMainBuilding(beacons: [CLBeacon]) {

        // filter the unknown proximity beacons, keep all others
        let knownBeaconsList = beacons.filter{ $0.proximity != CLProximity.Unknown }
        
        for beacon in knownBeaconsList {
            if pmaToolkit.settings.beaconVerboseLogging {
                pmaToolkit.logDebug("Beacon found: \(beacon.major)| \(beacon.minor), Proximity: \(beacon.proximity.rawValue), Accuracy: \(beacon.accuracy)")
            }
        }
        
        let filteredBeaconsList = knownBeaconsList.sort({$0.accuracy < $1.accuracy})
        
        for beacon in filteredBeaconsList {
            if let _ = self.getPMABeaconForCLBeacon(beacon) {
                self.addBeaconToBeaconsInRange(beacon, proximity: .Immediate)
            }
        }
        
    }
    
    func scanForMainBuildingBeaconsInRange() {
        // very useful: http://www.mathe-online.at/mathint/wstat2/i.html#VuS
        
        if self.areBeaconsLoaded() {
            
            for (i,beacon) in beaconsInRange.enumerate().reverse() {
                let timeSinceLastSeen = NSCalendar.currentCalendar().components(.Second, fromDate: beacon.lastSeen!, toDate: NSDate(), options: []).second
                //print("time since beacon was seen last: \(timeSinceLastSeen), \(object.name)")
                if timeSinceLastSeen >= pmaToolkit.settings.beaconTTL {
                    beaconsInRange.removeAtIndex(i)
                    pmaToolkit.logDebug("Removing beacon from range due to timeout: \(beacon.alias)")
                }
            }
            
            // First, we need to count the occurences for each beacon in our list
            let countForBeaconsInRange = self.countOccurenceForBeaconsInRange()
            
            // Second, we calculate the relative probability distribution for each beacon
            
            let probabilityForEachBeacon = self.calculateRelativeProbabilityDistributionForBeaconsInRange(countForBeaconsInRange)
            
            // Third, we want to map the beacons to their location and sum up the percentages
            
            let probabilityForEachLocation = self.calculateProbabilityForLocationsFromBeaconsInRange(probabilityForEachBeacon)
            
            // Fourth, add the rooms with the max percentage into another dict so we can run through
            // and determine the room with the highest probability overall
            
            if probabilityForEachLocation.count > 0 {
            
                if let currentLocation = self.assumeCurrentLocation(probabilityForEachLocation) {
                    self.updateCurrentLocation(currentLocation.location)
                    
                }
            } else {
                if self.beaconsInRange.count == 0 {
                        let timeSinceLastSeen = NSCalendar.currentCalendar().components(.Second, fromDate: self.unknownLocationTimestamp, toDate: NSDate(), options: []).second
                        if timeSinceLastSeen > 15 {
                            // notify
                            self.unknownLocationTimestamp = NSDate()
                            if self.currentLocation != nil {
                            pmaToolkit.postNotification("locationUnknown", parameters: ["lastKnownLocation" : self.currentLocation!])
                            } else {
                                pmaToolkit.postNotification("locationUnknown", parameters: nil)
                            }
                            pmaToolkit.logDebug("Posting location unknown notification")
                            //self.currentLocation = nil
                        }
                    
                }
            }
            
        }
    }
    
    private func updateCurrentLocation(location: pmaLocation) {
        if (self.currentLocation?.name == location.name) {
            // we haven't moved, still the same gallery
        } else {
            // we moved!
            pmaToolkit.logInfo("We moved! From: \(self.previousLocation?.name) To: \(location.name)")
            
            var objectsInCurrentLocation = "objects in current location: (\(location.objects.count)): "
            for object in location.objects {
                objectsInCurrentLocation = "\(objectsInCurrentLocation) \(object.title), "
            }
            pmaToolkit.logDebug(objectsInCurrentLocation)
            
            self.previousLocation = self.currentLocation
            self.currentLocation = location
            
            pmaToolkit.postNotification("locationChanged", parameters: ["currentLocation" : location])
        }
    }
    
    // MARK: Helper
    
    private func getPMABeaconForCLBeacon(originalBeacon: CLBeacon) -> pmaBeacon? {
        for beacon in self.beacons {
            if beacon.major == originalBeacon.major.integerValue && beacon.minor == originalBeacon.minor.integerValue {
                return beacon
            }
        }
        return nil
    }
    
    private func getLocationForBeacon(beacon: pmaBeacon!) -> pmaLocation? {
        for location in self.locations {
            if location.respondsToBeacon(beacon) {
                return location
            }
        }
        return nil
    }
    
    public func getCurrentLocation() -> pmaLocation? {
        return self.currentLocation
    }
    
    private func areBeaconsLoaded() -> Bool {
        return (self.beacons.count > 0)
    }
    
    private func areLocationsLoaded() -> Bool {
        return (self.locations.count > 0)
    }
    
    public func getLocationFromBeaconAlias(alias: String) -> pmaLocation? {
        let matches = pmaToolkit.matchesForRegexInText("[_][A-Z]{1}", text: alias)
        
        if matches.count > 0 {
            
            var result = alias
            for r in pmaToolkit.roomAliasReplacements {
                result = result.stringByReplacingOccurrencesOfString(r, withString: "")
            }
            return self.getLocationForName(result)
        } else {
            return nil
        }
    
    }
    
    private func getLocationForName(name: String) -> pmaLocation? {
        for location in self.locations {
            if location.name == name {
                return location
            }
        }
        return nil
    }
    
}