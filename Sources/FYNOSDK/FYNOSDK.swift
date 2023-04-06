#if os(iOS)
import UserNotifications
import UIKit
 
public class FYNOSDK {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var API_Key:String
    var WSID:String
    
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
    
    public func initializeApp(deviceToken: String)
    {
        Utilities.sendRequest(deviceToken: <#T##String#>, completionHandler: <#T##(Result<Bool, Error>) -> Void#>)
    }

    
    
}
#endif
