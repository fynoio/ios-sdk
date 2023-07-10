import Foundation
import RealmSwift

class NotificationPayloadDB: Object {
    @objc dynamic var id: ObjectId = ObjectId()
    @objc dynamic var to: String = ""
    @objc dynamic var ws_id: String = ""
    @objc dynamic var notification_content: String? = nil
    @objc dynamic var notification_settings: String? = nil
    @objc dynamic var status: String? = nil
    @objc dynamic var isRead: Bool = false
    @objc dynamic var createdAt: String? = nil
    @objc dynamic var updatedAt: String? = nil
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
public func saveNotification(_ notification: NotificationPayloadDB) {
//    Realm Database Migration Block [Danger Block Be-sure before un-commenting]
//    let realmURL = Realm.Configuration.defaultConfiguration.fileURL!
//    try! FileManager.default.removeItem(at: realmURL)
//    let config = Realm.Configuration(
//            schemaVersion: 1,
//            migrationBlock: { migration, oldSchemaVersion in
//                if oldSchemaVersion < 1 {
//                    // Add migration logic here if needed
//                }
//            })
//
//        Realm.Configuration.defaultConfiguration = config

        do {
            let realm = try Realm()
            try realm.write {
                realm.add(notification, update: .all)
            }
            print(Realm.Configuration.defaultConfiguration.fileURL!)
        } catch {
            print("Error saving notification: \(error)")
        }
 }
}

