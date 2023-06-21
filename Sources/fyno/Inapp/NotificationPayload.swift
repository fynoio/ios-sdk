//
//  File.swift
//
//
//  Created by Khush Chandawat on 14/06/23.
//

import Foundation

public struct NotificationPayload {
    public var id: String
    public var title: String
    public var body: String
    public var date: Date
    public var to: String
    public var isRead: Bool = false
    public var userInfo: [String: Any] // 'userInfo' will hold the whole notification content
    public var statuses: [[String: Any]] // 'statuses' seems to be a list of dictionaries
    
    init?(data: [String: Any]) {
        guard let id = data["_id"] as? String,
              let to = data["to"] as? String,
              let notificationContent = data["notification_content"] as? [String: Any],
              let title = notificationContent["title"] as? String,
              let body = notificationContent["body"] as? String,
              let statuses = data["status"] as? [[String: Any]],
              let createdAt = data["createdAt"] as? String,
              let date = Date(iso8601: createdAt) else {
            return nil
        }
        self.isRead = data["isRead"] as? Bool ?? false
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.to = to
        self.userInfo = notificationContent
        self.statuses = statuses
    }
    mutating func markAsRead()
    {
        self.isRead = true
    }
    
}

extension Date {
    init?(iso8601: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = dateFormatter.date(from: iso8601) else { return nil }
        self = date
    }
}

extension NotificationPayload {
    func toDictionary() -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let createdAt = dateFormatter.string(from: self.date)
        
        let dict: [String: Any] = [
            "title" : self.title,
            "_id": self.id,
            "body" : self.body,
            "to" : self.to,
            "notification_content": self.userInfo,
            "status": self.statuses,
            "createdAt": createdAt,
            "isRead" :  self.isRead
        ]
        
      
        
        return dict
    }
}
