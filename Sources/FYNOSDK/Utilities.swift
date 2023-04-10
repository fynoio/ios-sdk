#if os(iOS)
//
//  File.swift
//  
//
//  Created by Khush Chandawat on 05/04/23.
//

import Foundation
import UserNotifications
public class Utilities{
    static var url:String="https://api.dev.fyno.io"
    static var version:String="v1"
     
    
    
    public init(){
        
    }
    
    public static func downloadImageAndAttachToContent(from url: URL, content: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
        URLSession.shared.downloadTask(with: url) { (tempURL, _, error) in
            if let error = error {
                print("Error downloading attachment: \(error.localizedDescription)")
                completion(content)
                return
            }
            
            guard let tempURL = tempURL else {
                print("Temporary URL not found")
                completion(content)
                return
            }
            
            let fileManager = FileManager.default
            let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let fileExtension = URL(fileURLWithPath: url.absoluteString).pathExtension
            let localURL = cacheDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
            
            do {
                try fileManager.moveItem(at: tempURL, to: localURL)
                
                let attachment = try UNNotificationAttachment(identifier: "image", url: localURL, options: nil)
                content.attachments = [attachment]
            } catch {
                print("Error moving attachment to local URL: \(error.localizedDescription)")
            }
            
            completion(content)
        }.resume()
    }
    
    public static func createUserProfile(integrationID:String, payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        
        guard let url = URL(string: self.url+"/"+self.version+"/"+getWSID()+"/test/profiles") else {
                completionHandler(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("dev", forHTTPHeaderField: "version")
            request.addValue("Bearer "+getapi_key(), forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] =  [
                "distinct_id": payload.distinctID,
                "name": payload.name,
                "status": payload.status,
            "channel": [
                "sms": payload.sms,
                "push": [
                    [
                        "token": getdeviceToken(),
                        "integration_id": integrationID
                    ]
                    
                ]
            ]
        ]

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
                request.httpBody = jsonData
            } catch {
                completionHandler(.failure(NSError(domain: "JSON encoding failed", code: -1, userInfo: nil)))
                return
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completionHandler(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                    completionHandler(.failure(NSError(domain: "Invalid status code", code: -1, userInfo: nil )))
                    let httpResponse = response as? HTTPURLResponse
                         print(httpResponse?.statusCode)
                    
                    return
                }

                completionHandler(.success(true))
                 
          
            }
            task.resume()
        }
    
    public static func User_Profile_PayloadBuilder(payload:Payload)->Dictionary
    {
        var payload =
        [
            "distinct_id": "61",
            "name": "Shilpa Agarwal",
            "status": 1,
            "channel": [
                "sms": "+919902622877",
                "push": [
                    [
                        "token": deviceToken,
                        "integration_id": "I9F2D49242FEA"
                    ],
                    [
                        "token": "ttt2",
                        "integration_id": "I9F2D49242FEA"
                    ]
                ],
                "inapp": [
                    [
                        "token": "inapp_token:1",
                        "integration_id": nil
                    ],
                    [
                        "token": "inapp_token:1",
                        "integration_id": nil
                    ]
                ]
            ]
        ]
        
        return payload
    }
    
    public static func setUUID (UUID:String)->void
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "UUID"
        let currentLevel = UUID
        preferences.setString(currentLevel, forKey: currentLevelKey)
        //  Save to disk
        let didSave = preferences.synchronize()
        
        if !didSave {
        //  Couldn't save (I've never seen this happen in real world testing)
        }
    }
    
    public static func setWSID (WSID:String)->void
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "WSID"
        let currentLevel = WSID
        preferences.setString(currentLevel, forKey: currentLevelKey)
        //  Save to disk
        let didSave = preferences.synchronize()
        
        if !didSave {
        //  Couldn't save (I've never seen this happen in real world testing)
        }
    }
    
    public static func setapi_key (api_key:String)->void
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "api_key"
        let currentLevel = api_key
        preferences.setString(currentLevel, forKey: currentLevelKey)
        //  Save to disk
        let didSave = preferences.synchronize()
        
        if !didSave {
        //  Couldn't save (I've never seen this happen in real world testing)
        }
    }
    
 
    
    public static func setdeviceToken (deviceToken:String)->Void
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "deviceToken"
        let currentLevel = deviceToken
        preferences.setString(currentLevel, forKey: currentLevelKey)
        
        //  Save to disk
        if getdeviceToken()!==deviceToken {
            let didSave = preferences.synchronize()
            
            if !didSave {
                //  Couldn't save (I've never seen this happen in real world testing)
            }
        }
    }
    
    public static func getWSID ()->string
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "WSID"
        if preferences.objectForKey(currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.stringForKey(currentLevelKey)
        }
        return nil
    }
    
    public static func getapi_key ()->string
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "api_key"
        if preferences.objectForKey(currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.stringForKey(currentLevelKey)
        }
        return nil
        
    }
    
 
    
    public static func getdeviceToken ()->String
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "deviceToken"
        if preferences.objectForKey(currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.stringForKey(currentLevelKey)
        }
        return nil
    }
    
    public static func getUUID ()->String
    {
        let preferences = NSUserDefaults.standardUserDefaults()
        let currentLevelKey = "UUID"
        if preferences.objectForKey(currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.stringForKey(currentLevelKey)
        }
        return nil
    }
    
}
#endif
