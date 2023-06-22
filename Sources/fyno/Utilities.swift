#if os(iOS)
//
//  File.swift
//
//
//  Created by Khush Chandawat on 05/04/23.
//

import Foundation
import UIKit
import UserNotifications
import CommonCrypto
 class Utilities{
    private static var url:String="https://api.fyno.io"
    private static var environment=""
    private static var version:String="v1"
    private static let preferences = UserDefaults.standard
    private static let token_prefix = "apns_token:"
    
    
     
    
    
    private init(){
        
    }
    
     public static func downloadImageAndAttachToContent(from url: URL, content: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
         let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
             guard let data = data, let image = UIImage(data: data), let response = response else {
                 print("Error: \(String(describing: error))")
                 completion(content)
                 return
             }
             
             var imageData: Data?
             var fileExtension: String?
             
             if response.mimeType == "image/png" {
                 imageData = image.pngData()
                 fileExtension = "png"
             } else if response.mimeType == "image/jpeg" {
                 imageData = image.jpegData(compressionQuality: 1.0)
                 fileExtension = "jpeg"
             } else {
                 print("Unsupported MIME type: \(String(describing: response.mimeType))")
                 completion(content)
                 return
             }
             
             guard let imageData = imageData, let fileExtension = fileExtension else {
                 print("Could not convert image to data.")
                 completion(content)
                 return
             }
             
             let fileManager = FileManager.default
             let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
             let fileName = url.lastPathComponent
             let fileURL = cacheDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
             
             do {
                 if fileManager.fileExists(atPath: fileURL.path) {
                     try fileManager.removeItem(at: fileURL)
                 }
                 try imageData.write(to: fileURL)
                 
                 let attachment = try UNNotificationAttachment(identifier: "\(fileName).\(fileExtension)", url: fileURL, options: nil)
                 content.attachments = [attachment]
             } catch {
                 print("Error writing image data to local URL: \(error.localizedDescription)")
             }
             
             completion(content)
         }
         task.resume()
     }


    
    
    /******************************************************************************************/
    /******************************************************************************************/
    /********************************USER PROFILE CRUD******************************/
    /************************************OPERATIONS************************************/
    /******************************************************************************************/
    /******************************************************************************************/
    
    
    public static func createUserProfile(payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        
        guard let url = URL(string: self.url+"/"+self.version+"/"+getWSID()+self.environment+"/profiles") else {
                completionHandler(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("dev", forHTTPHeaderField: "version")
            request.addValue("Bearer "+getapi_key(), forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
            let pay_load: [String: Any] =  [
                "distinct_id": payload.distinctID,
                "name": payload.name,
                "status": payload.status,
            "channel": [
                 
                "push": [
                    [
                        "token": payload.pushToken,
                        "integration_id": payload.pushIntegrationID
                    ]
                    
                ]
            ]
        ]

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: pay_load, options: [])
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
                    //let httpResponse = response as? HTTPURLResponse
                     
                    
                    return
                }

                completionHandler(.success(true))
                 
          
            }
            task.resume()
        }
     
     public static func deleteChannelData(distinctID:String, channel:String, token:String,completionHandler: @escaping(Result<Bool,Error>) -> Void){
         
         guard let url = URL(string: self.url+"/"+self.version+"/"+getWSID()+self.environment+"/profiles/"+distinctID+"/channel/delete") else {
                 completionHandler(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
                 return
             }

             var request = URLRequest(url: url)
             request.httpMethod = "POST"
             request.addValue("dev", forHTTPHeaderField: "version")
             request.addValue("Bearer "+getapi_key(), forHTTPHeaderField: "Authorization")
             request.addValue("application/json", forHTTPHeaderField: "Content-Type")

             let payload: [String: Any] =  [
                channel : [token_prefix+token]
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
                     //let httpResponse = response as? HTTPURLResponse
                    // print(httpResponse?.statusCode ?? "404")
                     
                     
                     return
                 }

                 completionHandler(.success(true))
                  
           
             }
             task.resume()
     }
    
     
     public static func updateUserProfile(distinctID:String, payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
         
         guard let url = URL(string: self.url+"/"+self.version+"/"+getWSID()+self.environment+"/profiles/"+distinctID) else {
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
                     //let httpResponse = response as? HTTPURLResponse
                    // print(httpResponse?.statusCode ?? "404")
                     
                     
                     return
                 }

                 completionHandler(.success(true))
                  
           
             }
             task.resume()
         }
    
    
    
    public static func checkUserProfileExists(distinctId: String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = self.url+"/"+self.version+"/"+getWSID()+self.environment+"/profiles/"+distinctId
        guard let url = URL(string: urlString) else {
            completionHandler(.failure(NSError(domain: "fynosdk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
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
                completionHandler(.failure(NSError(domain: "fynosdk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            if httpResponse.statusCode == 200 {
                completionHandler(.success(true))
            } else if httpResponse.statusCode == 404 {
                completionHandler(.success(false))
            } else {
                completionHandler(.failure(NSError(domain: "fynosdk", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"])))
            }
        }
        task.resume()
    }
    
    
    
    
    public static func mergeUserProfile(payload:Payload,oldUUID:String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = self.url+"/"+self.version+"/"+getWSID()+self.environment+"/"+"profiles"+"/"+oldUUID+"/"+"merge"+"/"+payload.distinctID
            guard let url = URL(string: urlString) else {
                completionHandler(.failure(NSError(domain: "fynosdk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
        
//        let payload: [String: Any] =  [
//            "distinct_id": payload.distinctID,
//            "name": payload.name,
//            "status": payload.status,
//        "channel": [
//
//            "push": [
//                [
//                    "token": payload.pushToken,
//                    "integration_id": payload.pushIntegrationID
//                ]
//
//            ]
//        ]
//    ]

//            guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
//                completionHandler(.failure(NSError(domain: "fynosdk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data"])))
//                return
//            }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.addValue("dev", forHTTPHeaderField: "version")
            request.addValue("Bearer "+getapi_key(), forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//            request.httpBody = httpBody

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
                    completionHandler(.failure(NSError(domain: "fynosdk", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }

                if httpResponse.statusCode == 200 {
                    completionHandler(.success(true))
                } else {
                    completionHandler(.failure(NSError(domain: "fynosdk", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"])))
                }
            }
            task.resume()
        }
     
     public static func callback(url:String,action:String,deviceDetails: AnyHashable, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
         let urlString = url
             guard let url = URL(string: urlString) else {
                 completionHandler(.failure(NSError(domain: "fynosdk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                 return
             }
         
         let payload: [String: Any] =  [
             "status": action,
             "message": deviceDetails,
             "eventType": "Delivery",
         
     ]
         print(payload)

             guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
                 completionHandler(.failure(NSError(domain: "fynosdk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data"])))
                 return
             }

             var request = URLRequest(url: url)
             request.httpMethod = "POST"
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
                     completionHandler(.failure(NSError(domain: "fynosdk", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                     return
                 }

                 if httpResponse.statusCode == 200 {
                     completionHandler(.success(true))
                 } else {
                     completionHandler(.failure(NSError(domain: "fynosdk", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"])))
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
 
     /******************************************************************************************/
     /******************************************************************************************/
     /******************************************************************************************/
     /********************************OS Critical Functions*******************************/
     /******************************************************************************************/
     /******************************************************************************************/
     /******************************************************************************************/
     
    public static func getDeviceDetails() -> [String: String] {
        let device = UIDevice.current
        var details = [String: String]()
        details["name"] = device.name // e.g. "John's iPhone"
        details["model"] =  UIDevice.modelName // e.g. "iPhone"
        details["localizedModel"] = device.localizedModel // localized version of model
        details["systemName"] = device.systemName // e.g. "iOS"
        details["systemVersion"] = device.systemVersion // e.g. "12.1"
        details["identifierForVendor"] = device.identifierForVendor?.uuidString // unique identifier for the device
        return details
}
     
     public static func setEnvironment(production : Bool )
     {
         if production {
             environment = ""
         }
         else {
             environment = "/test"
         }
     }
     
     public static func hmacSha256(for data: String, key: String) -> String? {
             let keyData = key.data(using: .utf8)!
             let data = data.data(using: .utf8)!
             
             var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
             data.withUnsafeBytes { dataBytes in
                 keyData.withUnsafeBytes { keyBytes in
                     CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, keyBytes.count, dataBytes.baseAddress, dataBytes.count, &digest)
                 }
             }
             
             let output = digest.map { String(format: "%02x", $0) }.joined()
             return output
         }
     
     
    
}
#endif
