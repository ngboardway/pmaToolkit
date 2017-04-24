//
//  pmaCacheManager.swift
//  Pods
//
//  Created by Peter.Alt on 2/25/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import Foundation
import SwiftyJSON

public enum JSONType: Int {
    case beacon
    case location
}

open class pmaCacheManager {
    
    open static func loadJSONFile(_ endpoint: String, for jsonType:JSONType) -> JSON? {
        
        let localJSON = jsonType == .location ? pmaToolkit.settings.defaultLocationJSON : pmaToolkit.settings.defaultBeaconJSON
        
        if let data = self.getData(self.constructURLForEndpoint(endpoint), ignoreCache: true) {
            
            print("Remote JSON found")
            
            do {
            let jsonData = try JSON(data: data)
            if jsonData != JSON.null {
                return jsonData
            } else {
                return nil
            }
            } catch {
                
            }
            
        } else if let defaultJSONURL = Bundle.main.url(forResource: localJSON, withExtension: "json"),
            let data = self.getData(defaultJSONURL, ignoreCache: true) {
            
            print("Local JSON found")
            do {
            let jsonData = try JSON(data: data)
            
            if jsonData != JSON.null {
                return jsonData
            } else {
                return nil
            }
            } catch {
                
            }
        }
        else {
            print("FAILURE! NO JSON found")
            return nil
        }
        return nil
    }
    
    // MARK: Private
    
    fileprivate static func makeURLRequest(_ url: URL, ignoreCache: Bool = false) -> URLRequest {
        var cachePolicy = URLRequest.CachePolicy.returnCacheDataElseLoad
        if ignoreCache {
            cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        }
        let request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: pmaToolkit.settings.cacheSettings.requestTimeout)
        
        return request
    }
    
    fileprivate static func constructURLForEndpoint(_ endpoint : String) -> URL {
        
        print("constructing URL for end point \(pmaToolkit.settings.cacheSettings.hostProtocol + pmaToolkit.settings.cacheSettings.hostName + "/" + (endpoint as String))")
        
        return URL(string: pmaToolkit.settings.cacheSettings.hostProtocol + pmaToolkit.settings.cacheSettings.hostName + "/" + (endpoint as String))!
    }
    
    fileprivate static func getData(_ url: URL, ignoreCache: Bool = false) -> Data? {
        
        let request = self.makeURLRequest(url, ignoreCache: ignoreCache)
        var data: Data?
        do {
            data = try NSURLConnection.sendSynchronousRequest(request, returning: nil)
        } catch _ as NSError {
            data = nil
        }
        
        if data != nil {
            return data
        } else {
            return nil
        }
    }
    
}
