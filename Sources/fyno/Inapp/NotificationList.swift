//
//  File.swift
//  
//
//  Created by Khush Chandawat on 14/06/23.
//

import Foundation
import SwiftUI

@available(iOS 13.0, *)
public struct NotificationList: View {
    @ObservedObject var inappManager: fynoInapp
    
    public init(inappManager: fynoInapp) {
            self.inappManager = inappManager
        }
    
    public var body: some View {
        NavigationView {
            ZStack{
                if #available(iOS 14.0, *) {
                    List {
                        ForEach(inappManager.notifications.indices, id: \.self) { index in
                            NotificationView(notification: $inappManager.notifications[index], onRead: {
                                // Delete the notification
                                self.inappManager.markAsRead(notification: self.inappManager.notifications[index])
                                
                            })
                                .onAppear {
                                    // When the last item appears...
                                    if index == inappManager.notifications.count - 1 {
                                        // Trigger loading more items
                                        inappManager.loadMoreItems()
                                    }
                                }
                        }
                        .onDelete(perform: delete)
                        
                        
                        if inappManager.isFetching || !inappManager.isConnected {
                            LoadingView(inappManager: inappManager) // Shows a loading spinner when `isFetching` is true
                        }
                        
                    }
                    .navigationTitle("Notifications")
                } else {
                    // Fallback on earlier versions
                }
                
            }
            .onAppear {
                inappManager.connect()
            }
        }
    }
    
    func delete(at offsets: IndexSet) {
        offsets.sorted(by: >).forEach { index in
                let notification = inappManager.notifications[index]
                inappManager.deleteNotification(notification: notification)
                inappManager.notifications.remove(at: index)
            }
    }
    
}

@available(iOS 14.0, *)
struct LoadingView: View {
    @ObservedObject var inappManager: fynoInapp

        init(inappManager: fynoInapp) {
            self.inappManager = inappManager
        }
    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.0).edgesIgnoringSafeArea(.all)
            VStack {
                if !inappManager.isFetching{
                    ProgressView()
                        .scaleEffect(1.0, anchor: .center)
                        .padding()
                        .foregroundColor(Color.white)
                }
                Text("Loading...")
                    .font(.body)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

 







 







