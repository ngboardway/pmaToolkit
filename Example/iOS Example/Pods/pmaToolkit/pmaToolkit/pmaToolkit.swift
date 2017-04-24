//
//  pmaToolkit.swift
//  pmaToolkit
//
//  Created by Peter.Alt on 2/24/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import UIKit

public class pmaToolkit: NSObject {
    
    static var serialLoadingQueue = dispatch_queue_create("com.pma.serialLoadingQueue", DISPATCH_QUEUE_SERIAL);
    
    // MARK: Settings
    
    public struct settings {
        
        public static var iBeaconUUID = ""
        
        public static var scannedLocationBufferLength = 2
        
        public static var beaconVerboseLogging = false
        
        public static var beaconTTL : Int = 10
        
        public static var headingFilter : Double = 10 // degree
        
        public static var logLevel = 3
        
        public static let iBeaconIdentifier = "pmaHackathon"
        
        public static let maxBeaconsInRangeCount : Int = 20
        
        public struct cacheSettings {
            public static var requestTimeout : Double = 10 //secs
            public static var hostProtocol = ""
            public static var hostName = ""
            public static var urlBeacons = ""
            public static var urlLocations = ""
        }
        
    }
    
    public static let roomAliasReplacements = ["_L", "_R", "_C", "_T", "_M", "_B"]
    
    // MARK: Configuration successful
    
    public static func configurationIsValid() -> Bool {
        return (self.settings.cacheSettings.hostProtocol.characters.count > 0) && (self.settings.cacheSettings.hostName.characters.count > 0) && (self.settings.cacheSettings.hostName.characters.count > 0) && (self.settings.cacheSettings.urlBeacons.characters.count > 0) && (self.settings.cacheSettings.urlLocations.characters.count > 0) && (self.settings.iBeaconUUID.characters.count > 0)
    }
    
    // MARK: Notifications
    
    public static func registerNotification(object: AnyObject, function: String, type: String) {
        NSNotificationCenter.defaultCenter().addObserver(object, selector: Selector(function as String), name: type as String, object: nil)
    }
    
    public static func postNotification(type: String, parameters: [NSObject : AnyObject]?) {
        NSNotificationCenter.defaultCenter().postNotificationName(type, object: nil, userInfo: parameters)
    }
    
    public static func getObjectFromNotificationForKey(notification: NSNotification, key: String) -> AnyObject? {
        if let userInfo:Dictionary<String,AnyObject> = notification.userInfo as? Dictionary<String,AnyObject> {
            return userInfo[key]
        } else {
            return nil
        }
    }

    public static func allKeysForValueFromDictionary<K, V : Equatable>(dict: [K : V], val: V) -> [K] {
        return dict.filter{ $0.1 == val }.map{ $0.0 }
    }
    
    
    // MARK: Logging
    
    public static func logDebug(message: String) {
        self.log(message, logLevel: 4)
    }
    
    public static func logInfo(message: String) {
        self.log(message, logLevel: 3)
    }
    
    public static func logWarning(message: String) {
        self.log(message, logLevel: 2)
    }
    
    public static func logError(message: String) {
        self.log(message, logLevel: 1)
    }
    
    // 0: NONE, 1: ERROR, 2: WARNING, 3: INFO, 4: DEBUG
    private static func log(message: String, logLevel: Int = 0) {
        
        if logLevel <= self.settings.logLevel {
            
            dispatch_async(dispatch_get_main_queue()) {
                print("\(self.formatTimeFromDate(NSDate())): [\(self.getNameForLogLevel(logLevel))] \(message)")
            }
        }
    }

    /**
     Returns the name to use according to the passed LogLevel
     
     @param logLevel Bla
     
     @return A formatted string with the matching name
     */
    private static func getNameForLogLevel(logLevel: Int) -> String {
        
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
    
    public static func formatDate(date: NSDate) -> String {
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.LongStyle
        formatter.timeStyle = .MediumStyle
        
        return formatter.stringFromDate(date)
    }
    
    public static func formatTimeFromDate(date: NSDate) -> String {
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.NoStyle
        formatter.timeStyle = .MediumStyle
        
        return formatter.stringFromDate(date)
    }
    
    // MARK: Regex
    
    // http://stackoverflow.com/questions/27880650/swift-extract-regex-matches
    
    public static func matchesForRegexInText(regex: String!, text: String!) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [])
            let nsString = text as NSString
            let results = regex.matchesInString(text,
                options: [], range: NSMakeRange(0, nsString.length))
            return results.map { nsString.substringWithRange($0.range)}
        } catch let error as NSError {
            self.logError("Error matching string: \(error.localizedDescription)")
            return []
        }
    }

}

