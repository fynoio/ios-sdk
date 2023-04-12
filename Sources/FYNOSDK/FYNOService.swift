#if os(iOS)
//
//  File.swift
//  
//
//  Created by Khush Chandawat on 05/04/23.
//

import Foundation
import UserNotifications

public class FYNOService{
    public init() {}
    
    public static func handleDidReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let content = bestAttemptContent,
              let attachmentURLString = content.userInfo["urlImageString"] as? String,
              let attachmentURL = URL(string: attachmentURLString) else {
            contentHandler(request.content)
            return
        }
         
        Utilities.downloadImageAndAttachToContent(from: attachmentURL, content: content, completion: contentHandler)
    }
}
#endif
