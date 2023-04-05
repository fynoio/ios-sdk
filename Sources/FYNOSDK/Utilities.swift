#if os(iOS)
//
//  File.swift
//  
//
//  Created by Khush Chandawat on 05/04/23.
//

import Foundation
import UserNotifications
public class Utilities{
    
    public init(){
        
    }
    
    public static func downloadImageAndAttachToContent(from url: URL, content: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
        URLSession.shared.downloadTask(with: url) { (tempURL, _, error) in
            if let error = error {
                print("Error downloading attachment: \(error.localizedDescription)")
                completion(content)
                return
            }
            
            guard let tempURL = tempURL else {
                print("Temporary URL not found")
                completion(content)
                return
            }
            
            let fileManager = FileManager.default
            let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let fileExtension = URL(fileURLWithPath: url.absoluteString).pathExtension
            let localURL = cacheDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
            
            do {
                try fileManager.moveItem(at: tempURL, to: localURL)
                
                let attachment = try UNNotificationAttachment(identifier: "image", url: localURL, options: nil)
                content.attachments = [attachment]
            } catch {
                print("Error moving attachment to local URL: \(error.localizedDescription)")
            }
            
            completion(content)
        }.resume()
    }
}
#endif
