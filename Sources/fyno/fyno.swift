#if os(iOS)
import UserNotifications
import UIKit
 
<<<<<<<< HEAD:Sources/fynosdk/fynosdk.swift
public class fynosdk{
========
public class fyno{
>>>>>>>> 11-bug-fix-issue-with-naming-convention-and-dynamic-images:Sources/fyno/fyno.swift
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var payloadUserProfile: Payload?
    
    public init(){
        
    }
    
    public func requestNotificationAuthorization(completionHandler: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            completionHandler(granted)
        }
        let category = UNNotificationCategory(identifier: "image-notification", actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }
    
    
    
    
    public func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
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
    
    
    public  func notificationExtention(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let content = bestAttemptContent,
              let attachmentURLString = content.userInfo["urlImageString"] as? String,
              let attachmentURL = URL(string: attachmentURLString) else {
            contentHandler(request.content)
            return
        }
        
        Utilities.downloadImageAndAttachToContent(from: attachmentURL, content: content, completion: contentHandler)
    }
    
    public func createUserProfile(distinctID:String, name:String? = nil, sms:String? = nil, completionHandler: @escaping(Result<Bool,Error>) -> Void)
    {
        
        if distinctID == "" {
            print("Invalid WSID, api_key, distinctID or integration ID. Please check your configuration")
            return
        }
        
        let payloadInstance = Payload(
            distinctID: distinctID,
            name: name ?? distinctID,
            status: 1,
            pushToken: Utilities.getdeviceToken(),
            pushIntegrationID: Utilities.getintegrationID()
            
        )
        
        //        if((Utilities.getUUID()).isEmpty || Utilities.getUUID() != UIDevice.current.identifierForVendor?.uuidString)
        //        {
        //            return
        //        }
        
        Utilities.createUserProfile(payload: payloadInstance) { result in
            switch result {
            case .success(let success):
                Utilities.mergeUserProfile(payload: payloadInstance,oldUUID: Utilities.getUUID()){ result in
                    switch result {
                    case .success(let success):
                        Utilities.setUUID(UUID: distinctID)
                        completionHandler(.success(success))
                    case .failure(let error):
                       completionHandler(.failure(error))
                    }
                }
                completionHandler(.success(success))
            case .failure(let error):
                Utilities.mergeUserProfile(payload: payloadInstance,oldUUID: Utilities.getUUID()){ result in
                    switch result {
                    case .success(let success):
                        Utilities.setUUID(UUID: distinctID)
                        completionHandler(.success(success))
                    case .failure(let error):
                       completionHandler(.failure(error))
                    }
                }
                completionHandler(.failure(error))
            }
            
        }
        
    }
    
    public func initializeApp(WSID:String,api_key:String,integrationID:String,deviceToken:String,completionHandler:@escaping (Result<Bool,Error>) -> Void)
    {
        
        
        if (WSID != "" && api_key != "" && integrationID != "" && deviceToken != ""  ){
            Utilities.setWSID(WSID: WSID)
            Utilities.setapi_key(api_key: api_key)
            Utilities.setintegrationID(integrationID: integrationID)
            Utilities.setdeviceToken(deviceToken: deviceToken)
        }
        else{
            print("Invalid WSID, api_key, Integration ID or Device Token. Please check your configuration")
        }
        
        let UUID = UIDevice.current.identifierForVendor?.uuidString
        
        
        let payloadInstance = Payload(
            distinctID: UUID!,
            name: UUID!,
            status: 1,
            pushToken: deviceToken,
            pushIntegrationID:integrationID
            
        )
        
        //        if(!(Utilities.getUUID()).isEmpty)
        //        {
        //            return
        //        }
        
        Utilities.createUserProfile(payload: payloadInstance) { result in
            switch result {
            case .success(let success):
                Utilities.setUUID(UUID: UUID!)
                completionHandler(.success(success))
            case .failure(_):
               
                Utilities.updateUserProfile(distinctID: UUID!, payload: payloadInstance){ result in
                    switch result {
                    case .success(let success):
                        Utilities.setUUID(UUID: UUID!)
                        completionHandler(.success(success))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                    
                }
                
                
            }
        }
    }
    
    
    
    public func getDeviceToken() -> String
    {
        return Utilities.getdeviceToken()
    }
    
    public func deleteProfile(name:String? = nil, completionHandler:@escaping (Result<Bool,Error>) -> Void)
    {
        let UUID = UIDevice.current.identifierForVendor?.uuidString
        
        
        let payloadInstance = Payload(
            distinctID: UUID!,
            name: name ?? UUID!,
            status: 1,
            pushToken: Utilities.getdeviceToken(),
            pushIntegrationID:Utilities.getintegrationID()
            
        )
        
       
        
        
        Utilities.createUserProfile(payload: payloadInstance) { result in
            switch result {
            case .success(_):
                Utilities.deleteChannelData(distinctID: Utilities.getUUID(), channel: "push", token: Utilities.getdeviceToken()){result in
                    switch result{
                    case .success(let success):
                        Utilities.setUUID(UUID: UUID!)
                        completionHandler(.success(success))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
                
            case .failure(_):
                Utilities.updateUserProfile(distinctID: UUID!, payload: payloadInstance){ result in
                    switch result {
                    case .success(let success):
                        Utilities.deleteChannelData(distinctID: Utilities.getUUID(), channel: "push", token: Utilities.getdeviceToken()){result in
                            switch result{
                            case .success(let success):
                                Utilities.setUUID(UUID: UUID!)
                                completionHandler(.success(success))
                            case .failure(let error):
                                completionHandler(.failure(error))
                            }
                        }
                        completionHandler(.success(success))
                    case .failure(let error):
                  
                         
                        completionHandler(.failure(error))
                    }
                    
                }
                 
            }
        }
    }
}


#endif
