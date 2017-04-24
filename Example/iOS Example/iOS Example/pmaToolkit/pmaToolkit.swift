//
//  pmaToolkit.swift
//  pmaToolkit
//
//  Created by Peter.Alt on 2/24/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import UIKit

open class pmaToolkit: NSObject {
    
    static var serialLoadingQueue = DispatchQueue(label: "com.pma.serialLoadingQueue", attributes: []);
    static var APIToken = "76Jglqsr9lqZSez1G5yJgLi0s6i8xMFBeQp592Fy4E0UaEESiuzU8wtuF6rN" //Enter your PMA API Token here
    
    // MARK: Settings
    
    public struct settings {
        
        public static var defaultBeaconJSON = "hackathon-beacons"
        public static var defaultLocationJSON = "hackathon-locations"
        
        //default iBeacon 
        public static var iBeaconUUID = "f7826da6-4fa2-4e98-8024-bc5b71e0893e" //Enter your PMA API Token here
        public static var scannedLocationBufferLength = 2
        
        public static var beaconVerboseLogging = false
        
        public static var beaconTTL : Int = 10
        
        public static var headingFilter : Double = 10 // degree
        
        public static var logLevel = 4
        
        public static let iBeaconIdentifier = "pmaHackathon"
        
        public static let maxBeaconsInRangeCount : Int = 20
        
        public struct cacheSettings {
            public static var requestTimeout : Double = 10 //secs
            public static var hostProtocol = "https"
            public static var hostName = "hackathon.philamuseum.org"
            public static var urlBeacons = "/api/v0/collection/beacons?api_token=\(APIToken)"
            public static var urlLocations = "/philamuseum/hackathon/master/data/Hackathon-collectiondata.json"
        }
        
    }
    
    open static let roomAliasReplacements = ["_L", "_R", "_C", "_T", "_M", "_B"]
    
    // MARK: Configuration successful
    
    open static func configurationIsValid() -> Bool {
        return (self.settings.cacheSettings.hostProtocol.characters.count > 0) && (self.settings.cacheSettings.hostName.characters.count > 0) && (self.settings.cacheSettings.hostName.characters.count > 0) && (self.settings.cacheSettings.urlBeacons.characters.count > 0) && (self.settings.cacheSettings.urlLocations.characters.count > 0) && (self.settings.iBeaconUUID.characters.count > 0)
    }
    
    // MARK: Notifications
    
    open static func registerNotification(_ object: AnyObject, function: String, type: String) {
        NotificationCenter.default.addObserver(object, selector: Selector(function as String), name: NSNotification.Name(rawValue: type as String), object: nil)
    }
    
    open static func postNotification(_ type: String, parameters: [AnyHashable: Any]?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: type), object: nil, userInfo: parameters)
    }
    
    open static func getObjectFromNotificationForKey(_ notification: Notification, key: String) -> AnyObject? {
        if let userInfo:Dictionary<String,AnyObject> = notification.userInfo as? Dictionary<String,AnyObject> {
            return userInfo[key]
        } else {
            return nil
        }
    }

    open static func allKeysForValueFromDictionary<K, V : Equatable>(_ dict: [K : V], val: V) -> [K] {
        return dict.filter{ $0.1 == val }.map{ $0.0 }
    }
    
    
    // MARK: Logging
    
    open static func logDebug(_ message: String) {
        self.log(message, logLevel: 4)
    }
    
    open static func logInfo(_ message: String) {
        self.log(message, logLevel: 3)
    }
    
    open static func logWarning(_ message: String) {
        self.log(message, logLevel: 2)
    }
    
    open static func logError(_ message: String) {
        self.log(message, logLevel: 1)
    }
    
    // 0: NONE, 1: ERROR, 2: WARNING, 3: INFO, 4: DEBUG
    fileprivate static func log(_ message: String, logLevel: Int = 0) {
        
        if logLevel <= self.settings.logLevel {
            
            DispatchQueue.main.async {
                print("\(self.formatTimeFromDate(Date())): [\(self.getNameForLogLevel(logLevel))] \(message)")
            }
        }
    }

    /**
     Returns the name to use according to the passed LogLevel
     
     @param logLevel Bla
     
     @return A formatted string with the matching name
     */
    fileprivate static func getNameForLogLevel(_ logLevel: Int) -> String {
        
        switch logLevel
        {
        case 1:
            return "Error"
        case 2:
            return "Warning"
        case 3:
            return "Info"
        case 4:
            return "Debug"
        default:
            return "None"
        }
    }
    
    // MARK: Date Helpers
    open static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.long
        formatter.timeStyle = .medium
        
        return formatter.string(from: date)
    }
    
    open static func formatTimeFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.none
        formatter.timeStyle = .medium
        
        return formatter.string(from: date)
    }
    
    // MARK: Regex
    // http://stackoverflow.com/questions/27880650/swift-extract-regex-matches
    
    open static func matchesForRegexInText(_ regex: String!, text: String!) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [])
            let nsString = text as NSString
            let results = regex.matches(in: text,
                options: [], range: NSMakeRange(0, nsString.length))
            return results.map { nsString.substring(with: $0.range)}
        } catch let error as NSError {
            self.logError("Error matching string: \(error.localizedDescription)")
            return []
        }
    }

}

