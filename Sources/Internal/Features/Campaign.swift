//The MIT License (MIT)
//
//Copyright (c) 2016 Webtrekk GmbH
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
//"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
//distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject
//to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  Created by arsen.vartbaronov on 17/08/16.
//

import Foundation

class Campaign{
    
    let trackID: String
    static let campaignHasProcessed = "campaignHasProcessed"
    static let savedMediaCode = "mediaCode"
    private let sharedDefaults = UserDefaults.standardDefaults.child(namespace: "webtrekk")

    
    init(trackID: String){
        self.trackID = trackID
    }
    
    
    func processCampaign() {
        
        // check if compain is done already
        if let isCampaignSet = sharedDefaults.boolForKey(Campaign.campaignHasProcessed) where isCampaignSet { return
        }
        
        WebtrekkTracking.logger.logDebug("Campaign process is starting")
        
        // sent request
        
        let session = RequestManager.createUrlSession()
        guard let urlComponents = NSURLComponents(string: "https://appinstall.webtrekk.net/appinstall/v1/install") else {
            WebtrekkTracking.logger.logError("can't initializate URL for campaign")
            return
        }
        var queryItems = [NSURLQueryItem]()
        queryItems.append(NSURLQueryItem(name: "trackid", value: self.trackID))
        
        if let advID = Environment.advertisingIdentifierManager?.advertisingIdentifier where advID.UUIDString != "00000000-0000-0000-0000-000000000000" {
            queryItems.append(NSURLQueryItem(name: "aid", value: advID.UUIDString))
        }
        
        queryItems.append(NSURLQueryItem(name: "X-WT-UA", value: DefaultTracker.userAgent))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.URL else {
            WebtrekkTracking.logger.logError("can't construct URL for campaign")
            return
        }
        
        let task = session.dataTaskWithURL(url){ data, response, error in
            if let error = error {
                WebtrekkTracking.logger.logError("Install campaign request error:\(error)")
            } else {
                guard let responseGuard = response as? NSHTTPURLResponse else {
                    WebtrekkTracking.logger.logError("Install campaign response error:\(response)")
                    return
                }
                
                guard responseGuard.statusCode == 200 else {
                    WebtrekkTracking.logger.logDebug("No campaign for this applicaiton. Response:\(response)")
                    self.sharedDefaults.set(key: Campaign.campaignHasProcessed, to: true)
                    return
                }
                
                // parc response
                guard let dataG = data, let json = try? NSJSONSerialization.JSONObjectWithData(dataG, options: .AllowFragments),
                    let jsonMedia = json["mediacode"] as? String where jsonMedia.characters.split("=").count == 2 else {
                    
                    WebtrekkTracking.logger.logError("Incorrect JSON response:\(data)")
                    return
                }
            
               WebtrekkTracking.logger.logDebug("Media code is received:\(jsonMedia)")
            
               let mc = String(jsonMedia.characters.split("=")[1])
                
                guard !mc.isEmpty else {
                    WebtrekkTracking.logger.logError("media code length is zero")
                    return
                }
                
                self.sharedDefaults.set(key: Campaign.campaignHasProcessed, to: true)
                self.sharedDefaults.set(key: Campaign.savedMediaCode, to: mc)
            }
        }
        
        WebtrekkTracking.logger.logDebug("Campaign request is sent:\(url)")
        task.resume()
    }
    
    func getAndDeletSavedMediaCode() -> String?{
        let mediaCode = self.sharedDefaults.stringForKey(Campaign.savedMediaCode)
        
        if let _ = mediaCode {
            self.sharedDefaults.remove(key: Campaign.savedMediaCode)
        }
        
        return mediaCode
    }
    
}