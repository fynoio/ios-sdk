#if os(iOS)

import Foundation
import UIKit
import UserNotifications
import CommonCrypto
import SwiftyJSON

class Utilities{
    private static let preferences = UserDefaults.standard
        
    public static func addImageAndActionButtons(bestAttemptContent: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
        let declineAction = UNNotificationAction(identifier: "DECLINE_ACTION", title: "Decline", options: .destructive)
        
        let categoryIdentifier = bestAttemptContent.userInfo["category"] as! String
        
        bestAttemptContent.categoryIdentifier = categoryIdentifier
        
        let actions = bestAttemptContent.userInfo[AnyHashable("actions")] as? [[AnyHashable: Any]]
        
        let notificationActions = actions?.compactMap { actionDict -> UNNotificationAction? in
            guard let link = actionDict["link"] as? String, let title = actionDict["title"] as? String else {
                return nil
            }
            
            return UNNotificationAction(identifier: link, title: title)
        }
        
        var categoryActions = [declineAction]
        
        if let notificationActions = notificationActions, !notificationActions.isEmpty {
            categoryActions.insert(contentsOf: notificationActions, at: 0)
        }
        
        let category = UNNotificationCategory(identifier: categoryIdentifier, actions: categoryActions, intentIdentifiers: [], options: .customDismissAction)
        
        UNUserNotificationCenter.current().getNotificationCategories { categories in
            UNUserNotificationCenter.current().setNotificationCategories(categories.union(Set([category])))
        }
        
        // added this sleep as there are issues in rendering notifications with action buttons but no image
        Thread.sleep(forTimeInterval: 0.01)
        
        guard let attachmentURLString = bestAttemptContent.userInfo["urlImageString"] as? String,
              let attachmentURL = URL(string: attachmentURLString) else {
            completion(bestAttemptContent)
            return
        }
        
        let task = URLSession.shared.dataTask(with: attachmentURL) { (data, response, error) in
            guard let data = data, let image = UIImage(data: data), let response = response else {
                print("Error: \(String(describing: error))")
                completion(bestAttemptContent)
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
                completion(bestAttemptContent)
                return
            }
            
            guard let imageData = imageData, let fileExtension = fileExtension else {
                print("Could not convert image to data.")
                completion(bestAttemptContent)
                return
            }
            
            let fileManager = FileManager.default
            let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let fileName = attachmentURL.lastPathComponent
            let fileURL = cacheDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
            
            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                try imageData.write(to: fileURL)
                
                let attachment = try UNNotificationAttachment(identifier: "\(fileName).\(fileExtension)", url: fileURL, options: nil)
                bestAttemptContent.attachments = [attachment]
            } catch {
                print("Error writing image data to local URL: \(error.localizedDescription)")
            }
            
            completion(bestAttemptContent)
        }
        task.resume()
    }
    
    public static func createUserProfile(payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        let payload: JSON = [
            "distinct_id": payload.distinctID as Any,
            "status": payload.status as Any,
        ]
        
        RequestHandler.shared.PerformRequest(url: FynoUtils().getEndpoint(event: "create_profile"), method: "POST", payload: payload){ result in
            if case .failure(let error) = result {
                completionHandler(.failure(error))
                return
            } else if case .success(let success) = result {
                completionHandler(.success(success))
                return
            }
        }
    }
    
    public static func deleteChannelData(completionHandler: @escaping(Result<Bool,Error>) -> Void){
        let fcmToken = getFCMToken()
        let apnsToken = getAPNsToken()

        var pushArray: [String] = []

        if !fcmToken.isEmpty {
            pushArray.append(fcmToken)
        }

        if !apnsToken.isEmpty {
            pushArray.append(apnsToken)
        }

        let payload: JSON = [
            "push": pushArray
        ]
        
        RequestHandler.shared.PerformRequest(url: FynoUtils().getEndpoint(event: "delete_channel", profile: getDistinctID()), method: "POST", payload: payload){ result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
 
    public static func updateUserProfile(payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        let payloadInstance: JSON =  [
            "distinct_id": payload.distinctID as Any,
            "status": payload.status as Any,
            "channel": [
                "push": [
                    [
                        "token": getdeviceToken(),
                        "integration_id": getintegrationID()
                    ]
                ]
            ]
        ]
        
        RequestHandler.shared.PerformRequest(url: FynoUtils().getEndpoint(event: "upsert_profile", profile: payload.distinctID), method: "PUT", payload: payloadInstance){ result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public static func addChannelData(payload:Payload, completionHandler: @escaping (Result<Bool, Error>) -> Void){
 
        var isNotificationPermissionEnabled = 0
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("Authorized")
                isNotificationPermissionEnabled = 1
            case .denied:
                print("Denied")
            case .notDetermined:
                print("Not determined, asking user for permission now")
                fyno.app.requestNotificationAuthorization { granted in
                    if granted {
                        DispatchQueue.main.async {
                            fyno.app.registerForRemoteNotifications()
                        }
                    }
                }
            case .ephemeral:
                print("ephemeral")
            @unknown default:
                print("unknown status")
            }
            
            let payloadInstance: JSON =  [
                "channel": [
                    "push": [
                        [
                            "token": payload.pushToken as Any,
                            "integration_id": payload.integrationId as Any,
                            "status": isNotificationPermissionEnabled
                        ]
                    ]
                ]
            ]
            
            RequestHandler.shared.PerformRequest(url: FynoUtils().getEndpoint(event: "update_channel", profile: Utilities.getDistinctID()), method: "PATCH", payload: payloadInstance){ result in
                switch result {
                case .success(let success):
                    completionHandler(.success(success))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        }
    }
    
    public static func mergeUserProfile(newDistinctId:String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        if getDistinctID() == newDistinctId {
            completionHandler(.success(true))
            return
        }
            
        RequestHandler.shared.PerformRequest(url: FynoUtils().getEndpoint(event: "merge_profile", profile:  Utilities.getDistinctID(), newId: newDistinctId), method: "PATCH"){ result in
            switch result {
            case .success(let success):
                setDistinctID(distinctID: newDistinctId)
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
                return
            }
        }
    }
    
    public static func callback(url:String, action:String, deviceDetails: AnyHashable, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        var formattedDate: Any
        
        if #available(iOS 8.0, *) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
            formattedDate = dateFormatter.string(from: Date())
        } else {
            formattedDate = Date()
        }
        
        let payload: JSON =  [
            "status": action,
            "message": deviceDetails,
            "eventType": "Delivery",
            "timestamp": "\(action) at \(formattedDate)"
        ]
        
        RequestHandler.shared.PerformRequest(url: url, method: "POST", payload: payload){ result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public static func updateUserName(distinctID:String, userName:String, completionHandler: @escaping (Result<Bool,Error>) -> Void) {
        if getUserName() == userName {
            completionHandler(.success(true))
            return
        }
        
        let payloadInstance: JSON =  [
            "name": userName
        ]

        RequestHandler.shared.PerformRequest(url: FynoUtils().getEndpoint(event: "upsert_profile", profile: distinctID), method: "PUT", payload: payloadInstance){ result in
            switch result {
            case .success(let success):
                setUserName(userName: userName)
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public static func setUserName(userName:String) -> Void {
        let currentLevelKey = "userName"
        let currentLevel = userName
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getUserName ()-> String {
        let currentLevelKey = "userName"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func setWSID (WSID:String)->Void
    {
        let currentLevelKey = "WSID"
        let currentLevel = WSID
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getWSID ()-> String
    {
        let currentLevelKey = "WSID"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func setVersion (Version:String)->Void
    {
        let currentLevelKey = "version"
        let currentLevel = Version
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getVersion ()-> String?
    {
        let currentLevelKey = "version"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return nil
    }
    
    public static func setapi_key (api_key:String)->Void
    {
        let currentLevelKey = "api_key"
        let currentLevel = api_key
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getapi_key ()-> String
    {
        let currentLevelKey = "api_key"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func setintegrationID(integrationID:String)->Void
    {
        let currentLevelKey = "integrationID"
        let currentLevel = integrationID
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getintegrationID ()->String
    {
        let currentLevelKey = "integrationID"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
       
    public static func setdeviceToken (deviceToken:String)->Void
    {
        let currentLevelKey = "deviceToken"
        let currentLevel = deviceToken
        if getdeviceToken() != deviceToken {
            preferences.set(currentLevel, forKey: currentLevelKey)
        }
    }
    
    public static func getdeviceToken ()->String
    {
        let currentLevelKey = "deviceToken"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func setAPNsToken (apnsToken:String)->Void
    {
        let currentLevelKey = "apnsToken"
        preferences.set("apns_token:" + apnsToken,forKey: currentLevelKey)
    }
    
    public static func getAPNsToken ()->String
    {
        let currentLevelKey = "apnsToken"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func setFCMToken (fcmToken:String)->Void
    {
        let currentLevelKey = "fcmToken"
        preferences.set("fcm_token:" + fcmToken,forKey: currentLevelKey)
    }
    
    public static func getFCMToken ()->String
    {
        let currentLevelKey = "fcmToken"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func setDeviceTokenData(deviceTokenData: Data) {
        let currentLevelKey = "deviceTokenData"
        preferences.set(deviceTokenData, forKey: currentLevelKey)
    }
    
    public static func getDeviceTokenData() -> Data? {
        let currentLevelKey = "deviceTokenData"
        if let deviceTokenData = preferences.data(forKey: currentLevelKey) {
            return deviceTokenData
        }
        return nil
    }

    
    public static func setDistinctID(distinctID:String)->Void{
        let currentLevelKey = "distinctID"
        let currentLevel = distinctID
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getDistinctID ()->String
    {
        let currentLevelKey = "distinctID"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }
    
    public static func setFynoInitialized() -> Void{
        let currentLevelKey = "fynoInitialized"
        let currentLevel = true
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func isFynoInitialized () -> Bool
    {
        let currentLevelKey = "fynoInitialized"
        return preferences.bool(forKey: currentLevelKey)
    }
        
    public static func getDeviceDetails() -> [String: String] {
        let device = UIDevice.current
        var details = [String: String]()
        details["name"] = device.name
        details["model"] =  UIDevice.modelName
        details["localizedModel"] = device.localizedModel
        details["systemName"] = device.systemName
        details["systemVersion"] = device.systemVersion
        details["identifierForVendor"] = device.identifierForVendor?.uuidString 
        return details
    }
}
#endif
