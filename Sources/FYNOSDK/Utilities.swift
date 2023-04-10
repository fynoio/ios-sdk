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
    static let preferences = UserDefaults.standard
     
    
    
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
                    print(httpResponse?.statusCode ?? "404")
                    
                    return
                }

                completionHandler(.success(true))
                 
          
            }
            task.resume()
        }
    

    
    public static func setUUID (UUID:String) -> Void
    {
         
        let currentLevelKey = "UUID"
        let currentLevel = UUID
        self.preferences.set(currentLevel, forKey: currentLevelKey)
       
    }
    
    public static func setWSID (WSID:String)->Void
    {
        let currentLevelKey = "WSID"
        let currentLevel = WSID
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func setapi_key (api_key:String)->Void
    {
        let currentLevelKey = "api_key"
        let currentLevel = api_key
        preferences.set(currentLevel, forKey: currentLevelKey)
        
    }
    
 
    
    public static func setdeviceToken (deviceToken:String)->Void
    {
        let currentLevelKey = "deviceToken"
        let currentLevel = deviceToken
        if getdeviceToken() != deviceToken {
            preferences.set(currentLevel, forKey: currentLevelKey)
        }
        
        
            
    }
    
    public static func getWSID ()-> String
    {
        let currentLevelKey = "WSID"
        if preferences.object(forKey: currentLevelKey) == nil {
        } else {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func getapi_key ()-> String
    {
        let currentLevelKey = "api_key"
        if preferences.object(forKey: currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
 
    
    public static func getdeviceToken ()->String
    {
        let currentLevelKey = "deviceToken"
        if preferences.object(forKey: currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func getUUID ()->String
    {
        let currentLevelKey = "UUID"
        if preferences.object(forKey: currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
       return ""
    }
    
}
#endif
