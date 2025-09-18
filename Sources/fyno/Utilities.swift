#if os(iOS)

import Foundation
import UIKit
@preconcurrency import UserNotifications
import CommonCrypto
import SwiftyJSON

@objc
class Utilities : NSObject{
    nonisolated(unsafe) static let preferences = UserDefaults.standard
        
    @objc public static func addImageAndActionButtons(bestAttemptContent: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
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
    
    public static func createUserProfile(
        payload: Payload,
        forceCreate: Bool = false,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        let currentDistinctID = getDistinctID()
        let newDistinctID = payload.distinctID ?? ""
        
        if !currentDistinctID.isEmpty && newDistinctID.starts(with: "fytp:") && !forceCreate {
            completionHandler(.success(true))
            return
        }

        let finalizeProfileSetup: @Sendable (Bool, @escaping @Sendable (Result<Bool, Error>) -> Void) -> Void = { success, completion in
            setDistinctID(distinctID: newDistinctID)

            let fcmToken = getFCMToken()
            let apnsToken = getAPNsToken()
            let pushToken = !fcmToken.isEmpty ? fcmToken : apnsToken

            guard !pushToken.isEmpty else {
                completion(.success(true))
                return
            }

            let payloadInstance = Payload(
                pushToken: pushToken,
                integrationId: Utilities.getintegrationID()
            )

            Utilities.addChannelData(payload: payloadInstance) { channelResult in
                completion(channelResult)
            }
        }

        let handleCompletion: @Sendable (Result<Bool, Error>) -> Void = { result in
            switch result {
            case .success:
                deleteChannelData { deleteResult in
                    switch deleteResult {
                    case .failure(let error):
                        completionHandler(.failure(error))
                    case .success:
                        finalizeProfileSetup(true, completionHandler)
                    }
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }

        if currentDistinctID.isEmpty || !currentDistinctID.starts(with: "fytp:") || forceCreate {
            let jsonPayload: JSON = [
                "distinct_id": newDistinctID,
                "status": payload.status as Any,
            ]

            let url = FynoUtils().getEndpoint(event: "create_profile", profile: newDistinctID)
            RequestHandler.shared.PerformRequest(
                url: url,
                method: "POST",
                payload: jsonPayload,
                completionHandler: handleCompletion
            )
        } else {
            mergeUserProfile(
                oldDistinctId: currentDistinctID,
                newDistinctId: newDistinctID,
                isForceMerge: true,
                completionHandler: handleCompletion
            )
        }
    }

    
    public static func deleteChannelData(
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        let fcmToken = getFCMToken()
        let apnsToken = getAPNsToken()

        var pushArray: [String] = []

        if !fcmToken.isEmpty {
            pushArray.append(fcmToken)
        }

        if !apnsToken.isEmpty {
            pushArray.append(apnsToken)
        }
        
        if pushArray.isEmpty { // no channel data to delete
            completionHandler(.success(true))
            return
        }

        let payload: JSON = [
            "push": pushArray
        ]
        
        RequestHandler.shared.PerformRequest(
            url: FynoUtils().getEndpoint(event: "delete_channel", profile: getDistinctID()),
            method: "POST",
            payload: payload
        ) { @Sendable result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
 
    public static func updateUserProfile(
        payload: Payload,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        let payloadInstance: JSON = [
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
        
        RequestHandler.shared.PerformRequest(
            url: FynoUtils().getEndpoint(event: "upsert_profile", profile: payload.distinctID),
            method: "PUT",
            payload: payloadInstance
        ) { @Sendable result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public static func addChannelData(
        payload: Payload,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let permissionStatus: Int
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("Authorized")
                permissionStatus = 1
            case .denied:
                print("Denied")
                permissionStatus = 0
            case .notDetermined:
                print("Not determined, asking user for permission now")
                fyno.app.requestNotificationAuthorization { granted in
                    if granted {
                        DispatchQueue.main.async {
                            fyno.app.registerForRemoteNotifications()
                        }
                    }
                }
                permissionStatus = 0
            case .ephemeral:
                print("ephemeral")
                permissionStatus = 0
            @unknown default:
                print("unknown status")
                permissionStatus = 0
            }
            
            if permissionStatus != getPushPermission()
                || getDistinctID() != getPushDistinctID()
                || getPushPermissionFirstTime() == false {
                
                let payloadInstance: JSON = [
                    "channel": [
                        "push": [
                            [
                                "token": payload.pushToken as Any,
                                "integration_id": payload.integrationId as Any,
                                "status": permissionStatus
                            ]
                        ]
                    ]
                ]
                
                RequestHandler.shared.PerformRequest(
                    url: FynoUtils().getEndpoint(
                        event: "update_channel",
                        profile: Utilities.getDistinctID()
                    ),
                    method: "PATCH",
                    payload: payloadInstance
                ) { @Sendable result in
                    switch result {
                    case .success(let success):
                        setPushPermission(isNotificationPermissionEnabled: permissionStatus)
                        setPushDistinctID(fynoPushDistinctID: getDistinctID())
                        setPushPermissionFirstTime(value: true)
                        completionHandler(.success(success))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            } else {
                completionHandler(.success(true))
            }
        }
    }
    
    public static func setPushPermissionFirstTime(value:Bool) -> Void {
        let currentLevelKey = "pushPermissionFirstTime"
        let currentLevel = value
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getPushPermissionFirstTime() -> Bool {
        let currentLevelKey = "pushPermissionFirstTime"
        return preferences.bool(forKey: currentLevelKey)
    }
    
    public static func setPushPermission(isNotificationPermissionEnabled:Int)->Void {
        let currentLevelKey = "isNotificationPermissionEnabled"
        let currentLevel = isNotificationPermissionEnabled
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getPushPermission ()->Int {
        let currentLevelKey = "isNotificationPermissionEnabled"
        return preferences.integer(forKey: currentLevelKey)
    }
    
    public static func setPushDistinctID(fynoPushDistinctID:String)->Void {
        let currentLevelKey = "fyno_push_distinct_id"
        let currentLevel = fynoPushDistinctID
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getPushDistinctID ()->String {
        let currentLevelKey = "fyno_push_distinct_id"
        return preferences.string(forKey: currentLevelKey) ?? ""
    }
    
    public static func mergeUserProfile(
        oldDistinctId: String,
        newDistinctId: String,
        isForceMerge: Bool = false,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        let currentDistinctID = getDistinctID()

        guard currentDistinctID != newDistinctId else {
            completionHandler(.success(true))
            return
        }

        if currentDistinctID.starts(with: "fytp:") || isForceMerge {
            let url = FynoUtils().getEndpoint(
                event: "merge_profile",
                profile: oldDistinctId,
                newId: newDistinctId
            )
            RequestHandler.shared.PerformRequest(url: url, method: "PATCH") { @Sendable result in
                switch result {
                case .success:
                    setDistinctID(distinctID: newDistinctId)
                    completionHandler(.success(true))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        } else {
            deleteChannelData { @Sendable deleteResult in
                switch deleteResult {
                case .success:
                    let payload = Payload(distinctID: newDistinctId, status: 1)
                    createUserProfile(payload: payload) { @Sendable result in
                        switch result {
                        case .success:
                            completionHandler(.success(true))
                        case .failure(let error):
                            completionHandler(.failure(error))
                        }
                    }
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        }
    }
    
    public static func callback(
        url: String,
        action: String,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        let formattedDate: Any
        if #available(iOS 8.0, *) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
            formattedDate = dateFormatter.string(from: Date())
        } else {
            formattedDate = Date()
        }

        var updatedAction = action.uppercased()
        if !["RECEIVED", "CLICKED", "DISMISSED"].contains(updatedAction) {
            updatedAction = "UNKNOWN"
        }

        let payload: JSON = [
            "status": updatedAction,
            "eventType": "Delivery",
            "timestamp": "\(updatedAction) at \(formattedDate)"
        ]

        RequestHandler.shared.PerformRequest(
            url: url,
            method: "POST",
            payload: payload
        ) { @Sendable result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public static func updateUserName(
        userName: String,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        if getUserName() == userName {
            completionHandler(.success(true))
            return
        }
        
        let payloadInstance: JSON = [
            "name": userName
        ]

        RequestHandler.shared.PerformRequest(
            url: FynoUtils().getEndpoint(
                event: "upsert_profile",
                profile: getDistinctID()
            ),
            method: "PUT",
            payload: payloadInstance
        ) { @Sendable result in
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
        
    public static func setJWTToken(jwtToken:String)->Void{
        let currentLevelKey = "jwtToken"
        let currentLevel = jwtToken
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getJWTToken()->String{
        let currentLevelKey = "jwtToken"
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
        
    public static func setIntegrationIdForInapp (integrationIdForInApp:String)->Void{
        let currentLevelKey = "integrationIdForInApp"
        let currentLevel = integrationIdForInApp + "_" + Utilities.getDistinctID()
        preferences.set(currentLevel, forKey: currentLevelKey)
    }
    
    public static func getIntegrationIdForInapp()->String{
        let currentLevelKey = "integrationIdForInApp"
        if preferences.object(forKey: currentLevelKey) != nil {
            return preferences.string(forKey: currentLevelKey) ?? ""
        }
        return ""
    }

    @MainActor
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
