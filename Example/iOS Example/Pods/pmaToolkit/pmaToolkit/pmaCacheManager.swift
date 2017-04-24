//
//  pmaCacheManager.swift
//  Pods
//
//  Created by Peter.Alt on 2/25/16.
//  Copyright © 2016 Philadelphia Museum of Art. All rights reserved.
//

import Foundation
import SwiftyJSON

public class pmaCacheManager {
    
    public static func loadJSONFile(endpoint: String) -> JSON? {
        if let data = self.getData(self.constructURLForEndpoint(endpoint), ignoreCache: true) {
            let jsonData = JSON(data: data)
            
            if jsonData != nil {
                return jsonData
            } else {
                return nil
            }
        }
        else {
            return nil
        }
    }
    
    // MARK: Private
    
    private static func makeURLRequest(url: NSURL, ignoreCache: Bool = false) -> NSURLRequest {
        var cachePolicy = NSURLRequestCachePolicy.ReturnCacheDataElseLoad
        if ignoreCache {
            cachePolicy = .ReloadIgnoringLocalAndRemoteCacheData
        }
        let request = NSURLRequest(URL: url, cachePolicy: cachePolicy, timeoutInterval: pmaToolkit.settings.cacheSettings.requestTimeout)
        
        return request
    }
    

    private static func constructURLForEndpoint(endpoint : String) -> NSURL {
        return NSURL(string: pmaToolkit.settings.cacheSettings.hostProtocol + pmaToolkit.settings.cacheSettings.hostName + "/" + (endpoint as String))!
    }
    
    private static func getData(url: NSURL, ignoreCache: Bool = false) -> NSData? {
        
        let request = self.makeURLRequest(url, ignoreCache: ignoreCache)
        var data: NSData?
        do {
            data = try NSURLConnection.sendSynchronousRequest(request, returningResponse: nil)
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