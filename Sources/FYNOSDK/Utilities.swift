#if os(iOS)
//
//  File.swift
//  
//
//  Created by Khush Chandawat on 05/04/23.
//

import Foundation
import UserNotifications
 class Utilities{
    private static var url:String="https://api.dev.fyno.io"
    private static var environment="test"
    private static var version:String="v1"
    private static let preferences = UserDefaults.standard
    
     
    
    
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
    
    
    /******************************************************************************************/
    /******************************************************************************************/
    /********************************USER PROFILE CRUD******************************/
    /************************************OPERATIONS************************************/
    /******************************************************************************************/
    /******************************************************************************************/
    
    
    public static func createUserProfile(payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        
        guard let url = URL(string: self.url+"/"+self.version+"/"+getWSID()+"/"+self.environment+"/profiles") else {
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
                        "token": payload.pushToken,
                        "integration_id": payload.pushIntegrationID
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
                // Log response and data
                        if let data = data {
                            let dataString = String(data: data, encoding: .utf8) ?? "Non-string data received"
                            print("Response: \(dataString)")
                        }

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
     
     public static func deleteChannelData(distinctID:String, channel:String, token:String,completionHandler: @escaping(Result<Bool,Error>) -> Void){
         
         guard let url = URL(string: self.url+"/"+self.version+"/"+getWSID()+"/"+self.environment+"/profiles/channel/"+distinctID) else {
                 completionHandler(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
                 return
             }

             var request = URLRequest(url: url)
             request.httpMethod = "DELETE"
             request.addValue("dev", forHTTPHeaderField: "version")
             request.addValue("Bearer "+getapi_key(), forHTTPHeaderField: "Authorization")
             request.addValue("application/json", forHTTPHeaderField: "Content-Type")

             let payload: [String: Any] =  [
                channel : [token]
         ]

             do {
                 let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
                 request.httpBody = jsonData
             } catch {
                 completionHandler(.failure(NSError(domain: "JSON encoding failed", code: -1, userInfo: nil)))
                 return
             }

             let task = URLSession.shared.dataTask(with: request) { data, response, error in
                 // Log response and data
                         if let data = data {
                             let dataString = String(data: data, encoding: .utf8) ?? "Non-string data received"
                             print("Response: \(dataString)")
                         }

                         if let error = error {
                             completionHandler(.failure(error))
                             return
                         }

                 guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                     completionHandler(.failure(NSError(domain: "Invalid status code", code: -1, userInfo: nil )))
                     let httpResponse = response as? HTTPURLResponse
                     print(httpResponse?.statusCode ?? "404")
                     
                     
                     return
                 }

                 completionHandler(.success(true))
                  
           
             }
             task.resume()
     }
    
     
     public static func updateUserProfile(distinctID:String, payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
         
         guard let url = URL(string: self.url+"/"+self.version+"/"+getWSID()+"/"+self.environment+"/profiles/"+distinctID) else {
                 completionHandler(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
                 return
             }

             var request = URLRequest(url: url)
             request.httpMethod = "PUT"
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
                         "token": payload.pushToken,
                         "integration_id": payload.pushIntegrationID
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
                 // Log response and data
                         if let data = data {
                             let dataString = String(data: data, encoding: .utf8) ?? "Non-string data received"
                             print("Response: \(dataString)")
                         }

                         if let error = error {
                             completionHandler(.failure(error))
                             return
                         }

                 guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                     completionHandler(.failure(NSError(domain: "Invalid status code", code: -1, userInfo: nil )))
                     let httpResponse = response as? HTTPURLResponse
                     print(httpResponse?.statusCode ?? "404")
                     
                     
                     return
                 }

                 completionHandler(.success(true))
                  
           
             }
             task.resume()
         }
    
    
    
    public static func checkUserProfileExists(distinctId: String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = self.url+"/"+self.version+"/"+getWSID()+"/"+self.environment+"/profiles/"+distinctId
        guard let url = URL(string: urlString) else {
            completionHandler(.failure(NSError(domain: "FYNOSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("dev", forHTTPHeaderField: "version")
        request.addValue("Bearer "+getapi_key(), forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Log response and data
                    if let data = data {
                        let dataString = String(data: data, encoding: .utf8) ?? "Non-string data received"
                        print("Response: \(dataString)")
                    }

                    if let error = error {
                        completionHandler(.failure(error))
                        return
                    }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(NSError(domain: "FYNOSDK", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            if httpResponse.statusCode == 200 {
                completionHandler(.success(true))
            } else if httpResponse.statusCode == 404 {
                completionHandler(.success(false))
            } else {
                completionHandler(.failure(NSError(domain: "FYNOSDK", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"])))
            }
        }
        task.resume()
    }
    
    
    
    
    public static func mergeUserProfile(payload:Payload,oldUUID:String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = self.url+"/"+self.version+"/"+getWSID()+"/"+self.environment+"/profiles/merge/"+oldUUID
            guard let url = URL(string: urlString) else {
                completionHandler(.failure(NSError(domain: "FYNOSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
        
        let payload: [String: Any] =  [
            "distinct_id": payload.distinctID,
            "name": payload.name,
            "status": payload.status,
        "channel": [
            "sms": payload.sms,
            "push": [
                [
                    "token": payload.pushToken,
                    "integration_id": payload.pushIntegrationID
                ]
                
            ]
        ]
    ]

            guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
                completionHandler(.failure(NSError(domain: "FYNOSDK", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data"])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.addValue("dev", forHTTPHeaderField: "version")
            request.addValue("Bearer "+getapi_key(), forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                // Log response and data
                        if let data = data {
                            let dataString = String(data: data, encoding: .utf8) ?? "Non-string data received"
                            print("Response: \(dataString)")
                        }

                        if let error = error {
                            completionHandler(.failure(error))
                            return
                        }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completionHandler(.failure(NSError(domain: "FYNOSDK", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }

                if httpResponse.statusCode == 200 {
                    completionHandler(.success(true))
                } else {
                    completionHandler(.failure(NSError(domain: "FYNOSDK", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"])))
                }
            }
            task.resume()
        }
    
    
    
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************GETTERS AND SETTERS****************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
    
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
    
    public static func setintegrationID(integrationID:String)->Void
    {
        let currentLevelKey = "integrationID"
        let currentLevel = integrationID
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
    
    public static func getintegrationID ()->String
    {
        let currentLevelKey = "integrationID"
        if preferences.object(forKey: currentLevelKey) == nil {
            //  Doesn't exist
        } else {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
}
#endif
