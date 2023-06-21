//
//  File.swift
//  
//
//  Created by Khush Chandawat on 12/06/23.
//


import UIKit
import UserNotifications
import CoreData
import SocketIO


@available(iOS 13.0, *)
public class fynoInapp: ObservableObject {
    let socketURL:URL
    let userID:String
    let integrationToken:String
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    
    
    // private let context: NSManagedObjectContext
    
    @Published var notifications: [NotificationPayload] = []
    @Published var errorMessage: String = ""
    @Published var showConfig: Bool = false
    @Published var currentPage: Int = 1
    @Published var totalNotifications: Int = 0
    @Published var isFetching: Bool = false
    @Published var count: Int = 0
    @Published var isConnected: Bool = false
    
    public init(socketURL: URL, inappUserId: String, integrationToken: String) {
        
        self.socketURL = socketURL
        self.integrationToken = integrationToken
        self.userID = inappUserId
        
        
        // Assuming you have a setup Core Data stack
        //            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
        //                fatalError("AppDelegate unavailable")
        //            }
        //            self.context = appDelegate.persistentContainer.viewContext
    }
    
     func connect() {
        if(Utilities.getWSID() == "" || Utilities.getintegrationID() == "" || Utilities.getUUID() == "" ){
            print("iOS SDK is not initialized, please call the init method")
            return
        }
        
        
        
        let wsid = Utilities.getWSID()
        let integrationID = Utilities.getintegrationID()
        let key = wsid + self.integrationToken
        let  signature = Utilities.hmacSha256(for: self.userID, key: key) ?? ""
        let config: SocketIOClientConfiguration = [
            .extraHeaders([
                
                "x-fyno-signature": signature
            ]
                         ),
            .reconnects(true),
            .reconnectAttempts(-1),
            .reconnectWaitMax(5000)
        ]
        self.manager = SocketManager(socketURL: self.socketURL, config: config)
        
        socket = self.manager?.defaultSocket
        
        socket?.connect(withPayload: [
            "user_id": self.userID,
            "WS_ID": wsid,
            "Integration_ID": integrationID
        ])
        
        socket?.on(clientEvent: .connect) { (data, ack) in
            print("Socket connected")
            WebSocketManager.shared.isConnected = true
           
        }
        
        socket?.on("connect_error") { (data, ack) in
            // Handle new notifications, create a local notification, and store it
            // Assuming the incoming data has a "title" and "body"
            print(data)
            self.isConnected = false
            WebSocketManager.shared.isConnected = false
            
        }
        socket?.on("disconnect") { (data, ack) in
            // Handle new notifications, create a local notification, and store it
            // Assuming the incoming data has a "title" and "body"
            print(data)
            self.isConnected = false
            WebSocketManager.shared.isConnected = false
            
        }
        
        socket?.on("connectionSuccess") { (data, ack) in
            // Handle new notifications, create a local notification, and store it
            // Assuming the incoming data has a "title" and "body"
            print(data)
            self.isConnected = true
            self.fetchNotifications(page: 1)
            WebSocketManager.shared.isConnected = true
            
        }
        
         socket?.on("message") { (data, ack) in
             print(data[0])
             
             guard let dataDict = data[0] as? [String: Any],
                   let message = NotificationPayload(data: dataDict) else {
                 return
             }
             
             self.handleIncomingMessage(message: message)
             print(message.title)
             self.createNotification(title: message.title, body: message.body)
         }
        
         socket?.on("messages:state") {[weak self] data, ack in
             print(data)
             guard let self = self,
                   let stateData = data[0] as? [String: Any],
                   let messagesContainer = stateData["messages"] as? [String: Any],
                   let messages = messagesContainer["messages"] as? [[String: Any]],
                   let page = stateData["page"] as? Int else {
                 return
             }
            
             self.currentPage = page
             self.isFetching = false
             var newNotifications = messages.compactMap { NotificationPayload(data: $0) }
             if page > 1 {
                 newNotifications = self.notifications + newNotifications
             }
             self.notifications = newNotifications
         }

        
        socket?.on("statusUpdated") {[weak self] data, ack in
            print(data)
            guard let self = self,
                  let statusData = data[0] as? [String: Any],
                  let messageId = statusData["messageId"] as? String,
                  let status = statusData["status"] as? String else {
                return
            }
            self.handleStatusUpdate(status: status, messageId: messageId)
        }
        
    }
    
    func handleStatusUpdate(status: String, messageId: String) {
        guard let index = notifications.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        if status == "DELETED" {
            if !notifications[index].isRead {
                
                // Call your onMessageClicked delegate function here if you have one
                // onMessageClicked?("DELETED", messageId)
            }
        } else if status == "READ" {
            notifications[index].isRead = true
            
            // Call your onMessageClicked delegate function here if you have one
            // onMessageClicked?("READ", notifications[index])
        } else {
            //notifications[index].statuses.append(status)
        }
    }
    
    func fetchNotifications(page: Int) {
        print("fetching...")
        isFetching = true
        let data: [String: Any] = ["filter": "all", "page": page]
        socket?.emit("get:messages", with: [data])
        {
           print("fetch...")
        }
        }
    
    func handleIncomingMessage(message: NotificationPayload) {
        
        notifications.insert(message,  at: 0)
        count += 1
        totalNotifications += 1
       
    }
    
  

    public func loadMoreItems() {
        // Ensure you aren't already fetching more items
        guard !isFetching else { return }
        
        isFetching = true
       
        self.fetchNotifications(page: self.currentPage)
    } 

    
    
    
    
    
    func deleteNotification(notification: NotificationPayload) {
        print(notification.title)
        socket?.emit("message:deleted", notification.toDictionary()){
            if let index = self.notifications.firstIndex(where: { $0.id == notification.id }) {
                self.notifications.remove(at: index)
            }
        }
    }
    
    func markAsRead(notification: NotificationPayload) {
        socket?.emit("message:read", notification.toDictionary()){
        }
        
    }
    
    private func createNotification(title: String, body: String) {
        // Create a local notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    
    
    //    private func storeNotification(title: String, body: String) {
    //        // Store the notification in Core Data
    //        let newNotification = NotificationEntity(context: self.context)
    //        newNotification.title = title
    //        newNotification.body = body
    //
    //        do {
    //            try self.context.save()
    //        } catch {
    //            print("Failed to save notification: \(error)")
    //        }
    //    }
}
 
    


        



