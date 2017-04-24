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

open class pmaLocationManager : NSObject, CLLocationManagerDelegate {
    
    public enum locationSensingType : Int {
        case mainBuilding
    }
    
    open var objects = [pmaObject]()
    open var locations = [pmaLocation]()
    open var beacons = [pmaBeacon]()
    
    open var currentLocation : pmaLocation?
    open var previousLocation : pmaLocation?
    
    fileprivate let locationManager = CLLocationManager()
    
    fileprivate var beaconsInRange = [pmaBeacon]()
    fileprivate var locationsInRange = [[pmaLocation : Float]]()
    
    fileprivate var unknownLocationTimestamp = Date()
    fileprivate var sensingType : locationSensingType!
    
    // MARK: Init
    
    public override init() {
        super.init()
        self.locationManager.delegate = self
    }
    
    // MARK: Loading Remote Data
    
    fileprivate func loadBeacons(_ completionHandler: @escaping () -> ()) {
        pmaToolkit.logInfo("Loading beacons...")
        pmaToolkit.serialLoadingQueue.async {
            if let jsonData = pmaCacheManager.loadJSONFile(pmaToolkit.settings.cacheSettings.urlBeacons, for: .beacon) {
                if jsonData != JSON.null {
                    for (_, beaconValues): (String, JSON) in jsonData["devices"] {
                        
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
            } else {
                print("Didn't find JSON")
            }
            
            DispatchQueue.main.async {
                completionHandler()
                for beacon in self.beacons {
                    
                    pmaToolkit.logDebug("Beacon loaded: \(String(describing: beacon.alias)) - Major: \(beacon.major), Minor: \(beacon.minor)")
                    
                    if let location = self.getLocationFromBeaconAlias(beacon.alias!) {
                        location.beacons.append(beacon)
                        pmaToolkit.logDebug("Adding beacon \(String(describing: beacon.alias)) to location \(location.name)")
                    }
                }
                
                pmaToolkit.logInfo("Beacons loaded: \(self.beacons.count)")
            }
        }
    }
    
    fileprivate func loadLocations(_ completionHandler: @escaping () -> ()) {
        pmaToolkit.logInfo("Loading locations...")
        pmaToolkit.serialLoadingQueue.async {
            if let jsonData = pmaCacheManager.loadJSONFile(pmaToolkit.settings.cacheSettings.urlLocations, for: .location) {
                if jsonData != JSON.null {
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
                            if floor.lowercased() == "ground" {
                                newLocation.floor = pmaLocation.floors.ground
                            } else if floor.lowercased() == "first" {
                                newLocation.floor = pmaLocation.floors.first
                            } else if floor.lowercased() == "second" {
                                newLocation.floor = pmaLocation.floors.second
                            }
                        }
                        
                        if let type = locationValues["type"].string {
                            if type.lowercased() == "elevator" {
                                newLocation.type = pmaLocation.types.elevator
                            } else if type.lowercased() == "food" {
                                newLocation.type = pmaLocation.types.food
                            } else if type.lowercased() == "info" {
                                newLocation.type = pmaLocation.types.info
                            } else if type.lowercased() == "stairs" {
                                newLocation.type = pmaLocation.types.stairs
                            } else if type.lowercased() == "gallery" {
                                newLocation.type = pmaLocation.types.gallery
                            } else if type.lowercased() == "store" {
                                newLocation.type = pmaLocation.types.store
                            } else if type.lowercased() == "bathroom" {
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
            DispatchQueue.main.async {
                completionHandler()
                for location in self.locations {
                    pmaToolkit.logDebug("Location loaded: \(location.name) - Floor \(location.floor), Type: \(location.type), Enabled: \(location.enabled), Title: \(String(describing: location.title))")
                }
                pmaToolkit.logInfo("Locations loaded: \(self.locations.count)")
            }
        }
    }
    
    // MARK: Ranging Beacons

    open func startRangingBeacons(_ sensingType: locationSensingType) {
        if pmaToolkit.configurationIsValid() {
            
            if locations.count == 0 && beacons.count == 0 {
                
                self.loadLocations({
                    self.loadBeacons({
                        self.sensingType = sensingType
                        self.startRangingBeaconsInRegion()
                    })
                })
            }
            

        } else {
            pmaToolkit.logError("No valid configuration provided for iBeacon and Location definitions.")
        }
        
    }
    
    fileprivate func startRangingBeaconsInRegion() {
        if self.areBeaconsLoaded() {
            if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
                locationManager.requestWhenInUseAuthorization()
            }
            
            let region = CLBeaconRegion(proximityUUID: UUID(uuidString: pmaToolkit.settings.iBeaconUUID)!, identifier: pmaToolkit.settings.iBeaconIdentifier)
            
            locationManager.startRangingBeacons(in: region)
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            
            if self.sensingType == locationSensingType.mainBuilding {
                Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(pmaLocationManager.scanForMainBuildingBeaconsInRange), userInfo: nil, repeats: true)
            }
            
        } else {
            pmaToolkit.logError("No beacon definitions loaded. Cannot start ranging beacons")
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Entered Region
        pmaToolkit.logInfo("Enter region: \(region.identifier)")
    }
    
    open func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Exited Region
        pmaToolkit.logInfo("Exit region: \(region.identifier)")
    }
    
    open func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        if self.sensingType == locationSensingType.mainBuilding {
            self.processBeaconsForMainBuilding(beacons)
        }
    }
    
    // MARK: Heading
    
    open func startUpdateHeading() {
        pmaToolkit.logInfo("Start updating heading information")
        locationManager.headingFilter = pmaToolkit.settings.headingFilter
        locationManager.startUpdatingHeading()
    }

    open func stopUpdateHeading() {
        pmaToolkit.logInfo("Start updating heading information")
        locationManager.headingFilter = pmaToolkit.settings.headingFilter
        locationManager.stopUpdatingHeading()
    }
    
    open func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        let angle_in_degrees : CGFloat = CGFloat(newHeading.magneticHeading)
        let angle_in_radians = ((180 - (angle_in_degrees + 135)) * 3.1415) / 180.0
        
        pmaToolkit.postNotification("didUpdateHeading", parameters: ["actualHeadingDegrees" : newHeading, "calculatedHeadingRadians" : angle_in_radians])
    }
    
    // MARK: Location Calculation
    
    fileprivate func addBeaconToBeaconsInRange(_ beacon: CLBeacon, proximity: CLProximity) {
        
        if let matched = self.getPMABeaconForCLBeacon(beacon) {
            let matchedBeacon = matched.copy() as! pmaBeacon
            matchedBeacon.originalBeacon = beacon
            matchedBeacon.lastSeen = Date()
            
            var proximityName = ""
            
            switch proximity {
            case CLProximity.immediate :
                self.beaconsInRange.append(matchedBeacon)
                proximityName = "Immediate"
            case CLProximity.near :
                self.beaconsInRange.append(matchedBeacon)
                proximityName = "Near"
            case CLProximity.far :
                self.beaconsInRange.append(matchedBeacon)
                proximityName = "Far"
            default:
                pmaToolkit.logDebug("No beacon to append.")
            }
            
            pmaToolkit.logDebug("Adding to range: \(proximityName) - \(String(describing: matchedBeacon.alias)), ACC \(String(format: "%.2f", beacon.accuracy))m, RSSI \(beacon.rssi)dB, rangeCount: \(self.beaconsInRange.count)")
                
            pmaToolkit.postNotification("beaconFound", parameters: ["beaconFound" : matchedBeacon as Any])
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
            debugString += "\(count)x \(String(describing: beacon.alias))"
        }
        
        if !self.beaconsInRange.isEmpty && pmaToolkit.settings.beaconVerboseLogging {
            pmaToolkit.logDebug(debugString)
        }
        
        return countForEachBeacon
    }
    
    func calculateRelativeProbabilityDistributionForBeaconsInRange(_ listOfBeaconsWithOccurenceCount: [pmaBeacon : Int]) ->  [pmaBeacon : Float] {
        
        var percentageForEachBeacon = [pmaBeacon : Float]()
        var debugString = "Probability per beacon: "
        
        for (beacon, count) in listOfBeaconsWithOccurenceCount {
            
            percentageForEachBeacon[beacon] = Float(count) / Float(self.beaconsInRange.count)
            debugString += "\(String(describing: beacon.alias)): \(percentageForEachBeacon[beacon]!), "
        }
        
        if !listOfBeaconsWithOccurenceCount.isEmpty && pmaToolkit.settings.beaconVerboseLogging {
            pmaToolkit.logDebug(debugString)
        }
        
        return percentageForEachBeacon
    }
    
    func calculateProbabilityForLocationsFromBeaconsInRange(_ probabilityForEachBeacon : [pmaBeacon : Float]) -> [pmaLocation : Float] {
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
                locationPercentage.removeValue(forKey: location)
            }
        }
        
        return locationPercentage
    }
    
    func assumeCurrentLocation(_ probabilityForEachLocation: [pmaLocation : Float]) -> (location: pmaLocation, probability: Float)? {
        if self.areLocationsLoaded() {
        
            let maxPercentage = probabilityForEachLocation.values.max()
            let maxLocation = pmaToolkit.allKeysForValueFromDictionary(probabilityForEachLocation, val: maxPercentage!).first
            
            return (location: maxLocation!, probability: maxPercentage!)
            
        }
        return nil
    }
    
    fileprivate func processBeaconsForMainBuilding(_ beacons: [CLBeacon]) {

        // filter the unknown proximity beacons, keep all others
        let knownBeaconsList = beacons.filter{ $0.proximity != CLProximity.unknown }
        
        for beacon in knownBeaconsList {
            if pmaToolkit.settings.beaconVerboseLogging {
                pmaToolkit.logDebug("Beacon found: \(beacon.major)| \(beacon.minor), Proximity: \(beacon.proximity.rawValue), Accuracy: \(beacon.accuracy)")
            }
        }
        
        let filteredBeaconsList = knownBeaconsList.sorted(by: {$0.accuracy < $1.accuracy})
        
        for beacon in filteredBeaconsList {
            if let _ = self.getPMABeaconForCLBeacon(beacon) {
                self.addBeaconToBeaconsInRange(beacon, proximity: .immediate)
            }
        }
        
    }
    
    func scanForMainBuildingBeaconsInRange() {
        // very useful: http://www.mathe-online.at/mathint/wstat2/i.html#VuS
        
        if self.areBeaconsLoaded() {
            
            for (i,beacon) in beaconsInRange.enumerated().reversed() {
                let timeSinceLastSeen = (Calendar.current as NSCalendar).components(.second, from: beacon.lastSeen!, to: Date(), options: []).second
                //print("time since beacon was seen last: \(timeSinceLastSeen), \(object.name)")
                if timeSinceLastSeen! >= pmaToolkit.settings.beaconTTL {
                    beaconsInRange.remove(at: i)
                    pmaToolkit.logDebug("Removing beacon from range due to timeout: \(String(describing: beacon.alias))")
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
                    let timeSinceLastSeen = (Calendar.current as NSCalendar).components(.second, from: self.unknownLocationTimestamp, to: Date(), options: []).second
                    if timeSinceLastSeen! > 15 {
                        // notify
                        self.unknownLocationTimestamp = Date()
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
    
    fileprivate func updateCurrentLocation(_ location: pmaLocation) {
        if (self.currentLocation?.name == location.name) {
            // we haven't moved, still the same gallery
        } else {
            // we moved!
            pmaToolkit.logInfo("We moved! From: \(String(describing: self.previousLocation?.name)) To: \(location.name)")
            
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
    
    fileprivate func getPMABeaconForCLBeacon(_ originalBeacon: CLBeacon) -> pmaBeacon? {
        for beacon in self.beacons {
            if beacon.major == originalBeacon.major.intValue && beacon.minor == originalBeacon.minor.intValue {
                return beacon
            }
        }
        return nil
    }
    
    fileprivate func getLocationForBeacon(_ beacon: pmaBeacon!) -> pmaLocation? {
        for location in self.locations {
            if location.respondsToBeacon(beacon) {
                return location
            }
        }
        return nil
    }
    
    open func getCurrentLocation() -> pmaLocation? {
        return self.currentLocation
    }
    
    fileprivate func areBeaconsLoaded() -> Bool {
        return (self.beacons.count > 0)
    }
    
    fileprivate func areLocationsLoaded() -> Bool {
        return (self.locations.count > 0)
    }
    
    open func getLocationFromBeaconAlias(_ alias: String) -> pmaLocation? {
        let matches = pmaToolkit.matchesForRegexInText("[_][A-Z]{1}", text: alias)
        
        if matches.count > 0 {
            
            var result = alias
            for r in pmaToolkit.roomAliasReplacements {
                result = result.replacingOccurrences(of: r, with: "")
            }
            return self.getLocationForName(result)
        } else {
            return nil
        }
    
    }
    
    fileprivate func getLocationForName(_ name: String) -> pmaLocation? {
        for location in self.locations {
            if location.name == name {
                return location
            }
        }
        return nil
    }
    
}
