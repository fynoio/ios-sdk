//
//  File.swift
//  
//
//  Created by Khush Chandawat on 14/06/23.
//

import Foundation
import SwiftUI

@available(iOS 13.0, *)
struct NotificationView: View {
    @Binding var notification: NotificationPayload
    var onRead: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(notification.title)
                .font(.headline)
                .foregroundColor(notification.isRead ? .gray : .black)
            Text(notification.body)
                .foregroundColor(.gray)
            HStack {
                Spacer()
                Button(action: {
                     onRead?()
                }) {
                    Text("Mark as Read")
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 10)
                
            }
        }
        .padding()
    }
}


