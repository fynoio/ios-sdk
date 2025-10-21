import UserNotifications
import UIKit
import SwiftyJSON

@objc
public class fyno:UNNotificationServiceExtension, UNUserNotificationCenterDelegate {
    
    @objc nonisolated(unsafe) public static let app = fyno()
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var modifiedNotificationContent: UNMutableNotificationContent?
    
    @objc public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        
        // Start monitoring network changes
        ConnectionStateMonitor.shared.startMonitoring()
        
        // Add observer for network status changes
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChanged(_:)), name: ConnectionStateMonitor.networkStatusChangedNotification, object: nil)
    }
    
    deinit {
        // Stop monitoring
        ConnectionStateMonitor.shared.stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func networkStatusChanged(_ notification: Notification) {
        if let isConnected = notification.userInfo?["isConnected"] as? Bool {
            if isConnected {
                print("Connected to the network")
                RequestHandler.shared.processRequests() {_ in }
                RequestHandler.shared.processCBRequests() {_ in }
            }
        } else {
            print("Not connected to the network")
        }
    }
    
    public func initializeApp(
        workspaceID: String,
        integrationID: String,
        distinctId: String,
        version: String = "live",
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        guard !workspaceID.isEmpty && !integrationID.isEmpty else {
            let error = NSError(
                domain: "FynoSDK",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                           "workspaceID and/or integrationID cannot be empty. Please check your configuration"]
            )
            print(error.localizedDescription)
            completionHandler(.failure(error))
            return
        }
        
        SQLHelper.shared.updateAllRequestsToNotProcessed()
        
        Utilities.setWSID(WSID: workspaceID)
        Utilities.setintegrationID(integrationID: integrationID)
        Utilities.setVersion(Version: version)
        Utilities.setFynoInitialized()
        
        if !Utilities.getDistinctID().isEmpty &&
            !distinctId.isEmpty &&
            Utilities.getDistinctID() == distinctId {
            completionHandler(.success(true))
            return
        }
        
        let myUUID = UUID()
        var distinctIdToBeSent = "fytp:" + myUUID.uuidString
            
        if !distinctId.isEmpty {
            distinctIdToBeSent = distinctId
        }
        
        if Utilities.getDistinctID().starts(with: "fytp:") &&
            distinctIdToBeSent.starts(with: "fytp:") {
            completionHandler(.success(true))
            return
        }
        
        let payloadInstance = Payload(
            distinctID: distinctIdToBeSent,
            status: 1
        )
        
        Utilities.createUserProfile(payload: payloadInstance) { @Sendable result in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let success):
                print("Fyno instance initialized successfully")
                completionHandler(.success(success))
            }
        }
    }

    
    @objc public func setdeviceToken (deviceToken: Data) -> Void {
        let token = deviceToken.map { String(format: "%.2hhx", $0) }.joined()
        print("registered for remote notifications with token:\(token)")
        Utilities.setdeviceToken(deviceToken: token)
        Utilities.setDeviceTokenData(deviceTokenData: deviceToken)
    }

    public func getPushNotificationToken () -> String {
        var token = Utilities.getAPNsToken()
        if token == "" {
            token = Utilities.getFCMToken()
        }
        
        if token == "" {
            return token
        }
        
        return String(token.split(separator: ":", maxSplits: 1)[1])
    }
    
    public func registerPush(
        isAPNs: Bool,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [isAPNs] in
            
            @Sendable
            func complete(_ result: Result<Bool, Error>) {
                DispatchQueue.main.async {
                    completionHandler(result)
                }
            }
            
            guard Utilities.isFynoInitialized() else {
                let error = NSError(
                    domain: "FynoSDK",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "fyno instance not initialized"]
                )
                print(error.localizedDescription)
                complete(.failure(error))
                return
            }
            
            let payloadInstance = Payload(integrationId: Utilities.getintegrationID())
            
            if isAPNs {
                Utilities.setAPNsToken(apnsToken: Utilities.getdeviceToken())
                payloadInstance.pushToken = Utilities.getAPNsToken()
            } else {
                payloadInstance.pushToken = Utilities.getFCMToken()
            }
            
            if payloadInstance.pushToken == "apns_token:" || payloadInstance.pushToken == "fcm_token:" {
                let error = NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Push token not available"])
                print(error.localizedDescription)
                complete(.failure(error))
                return
            }
            
            Utilities.addChannelData(payload: payloadInstance) { result in
                complete(result)
            }
        }
    }

    public func setFCMToken(fcmToken:String){
        Utilities.setFCMToken(fcmToken: fcmToken)
    }
    
    public func registerInapp(integrationID: String, completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void){
        if !Utilities.isFynoInitialized() {
            let error = NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "fyno instance not initialized"])
            print(error.localizedDescription)
            completionHandler(.failure(error))
            return
        }
        
        if Utilities.getIntegrationIdForInapp() == integrationID + "_" + Utilities.getDistinctID() {
            completionHandler(.success(true))
            return
        }
        
        let payloadInstance: JSON =  [
            "channel": [
                "inapp": [
                    [
                        "token": Utilities.getDistinctID(),
                        "integration_id": integrationID,
                        "status": 1
                    ]
                ]
            ]
        ]
        
        RequestHandler.shared.PerformRequest(url: FynoUtils().getEndpoint(event: "update_channel", profile: Utilities.getDistinctID()), method: "PATCH", payload: payloadInstance){ result in
            switch result {
            case .success(let success):
                Utilities.setIntegrationIdForInapp(integrationIdForInApp: integrationID)
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public func identify(
        newDistinctId: String,
        userName: String,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        if !Utilities.isFynoInitialized() {
            let error = NSError(
                domain: "FynoSDK",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "fyno instance not initialized"]
            )
            print(error.localizedDescription)
            completionHandler(.failure(error))
            return
        }
        
        Utilities.mergeUserProfile(
            oldDistinctId: Utilities.getDistinctID(),
            newDistinctId: newDistinctId,
            isForceMerge: false
        ) { @Sendable result in
            switch result {
            case .success:
                print("merge successful")
                if !userName.isEmpty {
                    Utilities.updateUserName(userName: userName) { @Sendable result in
                        switch result {
                        case .success(let success):
                            completionHandler(.success(success))
                        case .failure(let error):
                            completionHandler(.failure(error))
                        }
                    }
                } else {
                    completionHandler(.success(true))
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public func updateName(
        userName: String,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        if !Utilities.isFynoInitialized() {
            let error = NSError(
                domain: "FynoSDK",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "fyno instance not initialized"]
            )
            print(error.localizedDescription)
            completionHandler(.failure(error))
            return
        }
        
        Utilities.updateUserName(userName: userName) { @Sendable result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    public func mergeProfile(
        oldDistinctId: String,
        newDistinctId: String,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        if !Utilities.isFynoInitialized() {
            let error = NSError(
                domain: "FynoSDK",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "fyno instance not initialized"]
            )
            print(error.localizedDescription)
            completionHandler(.failure(error))
            return
        }
        
        Utilities.mergeUserProfile(
            oldDistinctId: oldDistinctId,
            newDistinctId: newDistinctId,
            isForceMerge: true
        ) { @Sendable result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    public func updateStatus(
        callbackUrl: String,
        status: String,
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        Utilities.callback(url: callbackUrl, action: status) { @Sendable result in
            switch result {
            case .success(let success):
                completionHandler(.success(success))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    
    public func resetUser(
        completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        if !Utilities.isFynoInitialized() {
            let error = NSError(
                domain: "FynoSDK",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "fyno instance not initialized"]
            )
            print(error.localizedDescription)
            completionHandler(.failure(error))
            return
        }
        
        if Utilities.getDistinctID().starts(with: "fytp:") {
            print("can't reset temporary profile")
            completionHandler(.success(true))
            return
        }
        
        Utilities.deleteChannelData() { @Sendable result in
            switch result {
            case .success(let success):
                print("success delete channel")
                completionHandler(.success(success))
                
                let myUUID = UUID()
                let distinctID = "fytp:" + myUUID.uuidString
                let payloadInstance = Payload(distinctID: distinctID)
                
                Utilities.createUserProfile(payload: payloadInstance, forceCreate: true) { @Sendable result in
                    switch result {
                    case .success(let success):
                        print("success create user")
                        Utilities.setDistinctID(distinctID: distinctID)
                        let payload = Payload(integrationId: Utilities.getintegrationID())
                        
                        if !Utilities.getAPNsToken().isEmpty {
                            let apnsPayload = payload
                            apnsPayload.pushToken = Utilities.getAPNsToken()
                            Utilities.addChannelData(payload: apnsPayload) { @Sendable result in
                                switch result {
                                case .success:
                                    print("addChannelData success")
                                case .failure(let error):
                                    print(error.localizedDescription)
                                }
                            }
                        }
                        
                        if !Utilities.getFCMToken().isEmpty {
                            let fcmPayload = payload
                            fcmPayload.pushToken = Utilities.getFCMToken()
                            Utilities.addChannelData(payload: fcmPayload) { @Sendable result in
                                switch result {
                                case .success:
                                    print("addChannelData success")
                                case .failure(let error):
                                    print(error.localizedDescription)
                                }
                            }
                        }
                        completionHandler(.success(success))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    public func requestNotificationAuthorization(completionHandler: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            
            if !Utilities.getintegrationID().isEmpty {
                self.registerPush(isAPNs: Utilities.getFCMToken().isEmpty) { result in
                    switch result {
                    case .success(let success):
                        print(success)
                    case .failure(let error):
                        print(error)
                    }
                }
            }
            
            completionHandler(granted)
        }
    }
    
    @objc public func registerForRemoteNotifications() {
       Task {@MainActor in
            UIApplication.shared.registerForRemoteNotifications()
       }
    }
    
    @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // The notification was received while the app is active. Handle here. 
        // If you want to show the notification while the app is active, call the completion handler with .banner or .list
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            print("unsupported ios version, ios version less than 14.0")
        }
    }
          
    @objc public func handleDidReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else{
            contentHandler(request.content)
            return
        }
        
        var callbackUrl : String = ""
        print("Notification recieved")
        
        let provider = request.content.userInfo["provider"] as? String
        
        if provider == "fcm" {
            let json = JSON.init(parseJSON: (request.content.userInfo["extraData"] as? String)!)
            callbackUrl = json["callback"].stringValue
        }
        
        if provider == "apns" {
            if let alert = request.content.userInfo["extraData"] as? [String: Any] {
                callbackUrl = alert["callback"] as? String ?? ""
            }
        }
        
        if !callbackUrl.isEmpty {
            Utilities.callback(url: callbackUrl, action: "RECEIVED"){result in
                switch(result)
                {
                case .success(let success):
                    print(success)
                case .failure(let failure):
                    print(failure)
                }
            }
        }
        
        
        Utilities.addImageAndActionButtons(bestAttemptContent: bestAttemptContent, completion: contentHandler)
    }
            
    @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        var callbackUrl : String = ""
        
        let provider = content.userInfo["provider"] as? String
        
        if provider == "fcm" {
            let json = JSON.init(parseJSON: (content.userInfo["extraData"] as? String)!)
            callbackUrl = json["callback"].stringValue
        }
        
        if provider == "apns" {
            if let alert = content.userInfo["extraData"] as? [String: Any] {
                callbackUrl = alert["callback"] as? String ?? ""
            }
        }
        
        var action: String = ""
        var additionalDataString = "{}"
        
        if let additionalData = content.userInfo["extraData"] as? [String: Any] {
            let json = JSON(additionalData)
            if let jsonString = json.rawString() {
                additionalDataString = jsonString
            } else {
                print("Failed to convert dictionary to JSON string")
            }
        } else {
            print("extraData is not a valid dictionary")
        }
        
        if response.actionIdentifier == UNNotificationDismissActionIdentifier || response.actionIdentifier == "DECLINE_ACTION"{
            // The user dismissed the notification.
            print("Notification Dismissed")
            NotificationCenter.default.post(name: NSNotification.Name("onNotificationDismissed"), object: additionalDataString)
            action = "DISMISSED"
        } else {
            print("Notification Clicked")
            NotificationCenter.default.post(name: NSNotification.Name("onNotificationClicked"), object: additionalDataString)
            action = "CLICKED"
        }
        
        if !callbackUrl.isEmpty
        {
            Utilities.callback(url: callbackUrl, action: action){result in
                switch(result)
                {
                case .success(let success):
                    print(success)
                case .failure(let failure):
                    print(failure)
                }
            }
        }
        
        // To call URL on notification click
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let destinationURLString = content.userInfo["destination_url"] as? String {
                guard let url = URL(string: destinationURLString) else {
                    completionHandler()
                    return
                }
                
                Task{@MainActor in
                    UIApplication.shared.open(url) { (result) in
                        if result {
                            print("successfully opened deeplink")
                        }
                    }
                }
            }
        }
        
        // To call URL on button click
        if response.actionIdentifier != UNNotificationDismissActionIdentifier &&
           response.actionIdentifier != "DECLINE_ACTION" &&
            response.actionIdentifier != UNNotificationDefaultActionIdentifier {
            guard let url = URL(string: response.actionIdentifier) else {
                completionHandler()
                return
            }
            
            Task{@MainActor in
                UIApplication.shared.open(url)
            }
        }
        
        completionHandler()
    }
    
    @available(iOS 14.0, *)
    public func handleNotification(userInfo: [AnyHashable: Any], completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            completionHandler([])
            return
        }
        print("recieved notification")
        
        let content = UNMutableNotificationContent()
        
        if let alert = aps["alert"] as? [String: Any] {
            content.title = alert["title"] as? String ?? ""
            content.subtitle = alert["subtitle"] as? String ?? ""
            content.body = alert["body"] as? String ?? ""
        }
        
        if let badge = aps["badge"] as? NSNumber {
            content.badge = badge
        }
        
        if let sound = aps["sound"] as? String {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        }
        
        if let attachments = aps["attachments"] as? [[String: Any]] {
            var unAttachments: [UNNotificationAttachment] = []
            
            for attachment in attachments {
                guard let identifier = attachment["identifier"] as? String,
                      let url = attachment["url"] as? String,
                      let fileURL = URL(string: url),
                      let type = attachment["type"] as? String else { continue }
                
                if ["image", "icon"].contains(type) {
                    do {
                        print("image found")
                        let options: [String: Any]?
                        if type == "icon" {
                            options = [UNNotificationAttachmentOptionsThumbnailHiddenKey: true]
                        } else {
                            options = nil
                        }
                        
                        let unAttachment = try UNNotificationAttachment(identifier: identifier, url: fileURL, options: options)
                        unAttachments.append(unAttachment)
                    } catch {
                        print("Error creating notification attachment: \(error)")
                    }
                }
            }
            content.attachments = unAttachments
        }
        completionHandler([.banner, .sound])
    }
}
