import FMDB
import SwiftyJSON

class SQLHelper: @unchecked Sendable {
    static let shared = SQLHelper() // Singleton instance
    
    struct DatabaseConstants {
        static let databaseName = "fyno.db"
        static let reqTableName = "requests"
        static let cbTableName = "callbacks"
        static let columnId = "id"
        static let columnUrl = "url"
        static let columnPostData = "post_data"
        static let columnMethod = "method"
        static let columnLastProcessedAt = "last_processed_at"
        static let columnStatus = "status"
    }
        
    private var databaseQueue: FMDatabaseQueue? = nil
        
    private init() {
        // Private initializer to enforce singleton pattern
        setupDatabase()
    }
    
    private func setupDatabase() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to get the documents directory.")
        }
        
        let databasePath = documentsDirectory.appendingPathComponent("\(DatabaseConstants.databaseName).sqlite")
        
        // Initialize the FMDatabase queue
        databaseQueue = FMDatabaseQueue(path: databasePath.path)
        
        // Open the database
        databaseQueue?.inDatabase {database in
            if !(database.open()) {
                fatalError("Unable to open the database.")
            }
        }
        
        
        // Create tables, perform initial setup, etc.
        createTables()
    }
        
    private func createTables() {
        // Add your table creation SQL statements here
        let createReqTableQuery = """
            CREATE TABLE IF NOT EXISTS \(DatabaseConstants.reqTableName) (
                \(DatabaseConstants.columnId) INTEGER PRIMARY KEY AUTOINCREMENT,
                \(DatabaseConstants.columnUrl) TEXT,
                \(DatabaseConstants.columnPostData) TEXT,
                \(DatabaseConstants.columnMethod) TEXT,
                \(DatabaseConstants.columnLastProcessedAt) TIMESTAMP,
                \(DatabaseConstants.columnStatus) TEXT DEFAULT 'not_processed'
            )
        """
        
        let createCBTableQuery = """
            CREATE TABLE IF NOT EXISTS \(DatabaseConstants.cbTableName) (
                \(DatabaseConstants.columnId) INTEGER PRIMARY KEY AUTOINCREMENT,
                \(DatabaseConstants.columnUrl) TEXT,
                \(DatabaseConstants.columnPostData) TEXT,
                \(DatabaseConstants.columnMethod) TEXT,
                \(DatabaseConstants.columnLastProcessedAt) TIMESTAMP,
                \(DatabaseConstants.columnStatus) TEXT DEFAULT 'not_processed'
            )
        """

        databaseQueue?.inDatabase {database in
            do {
                try database.executeUpdate(createReqTableQuery, values: nil)
                try database.executeUpdate(createCBTableQuery, values: nil)
            } catch {
                print("Error creating table: \(error.localizedDescription)")
            }
        }
    }
    
    func updateStatusAndLastProcessedTime(id: Int?, tableName: String, status: String) {
        guard let id = id, id != 0 else {
            return
        }
        
        let updateQuery = """
            UPDATE \(tableName) SET
            \(DatabaseConstants.columnStatus) = ?,
            \(DatabaseConstants.columnLastProcessedAt) = ?
            WHERE \(DatabaseConstants.columnId) = ?
        """
        
        databaseQueue?.inDatabase {database in
            do {
                try database.executeUpdate(updateQuery, values: [status, self.getCurrentTimestamp(), id])
            } catch {
                print("Error updating status and last processed time: \(error.localizedDescription)")
                
            }
        }
    }
        
    func updateAllRequestsToNotProcessed() {
        let updateRequestQuery = """
            UPDATE \(DatabaseConstants.reqTableName) SET
            \(DatabaseConstants.columnStatus) = ?,
            \(DatabaseConstants.columnLastProcessedAt) = ?
        """
        
        let updateCBQuery = """
            UPDATE \(DatabaseConstants.cbTableName) SET
            \(DatabaseConstants.columnStatus) = ?,
            \(DatabaseConstants.columnLastProcessedAt) = ?
        """
        
        databaseQueue?.inDatabase {database in
            do {
                try database.executeUpdate(updateRequestQuery, values: ["not_processed", self.getCurrentTimestamp()])
                try database.executeUpdate(updateCBQuery, values: ["not_processed", self.getCurrentTimestamp()])
            } catch {
                print("Error updating all requests to not processed: \(error.localizedDescription)")
            }
        }
    }
    
    private func getCurrentTimestamp() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func insertRequest(request: RequestHandler.Request, tableName: String) {
        let insertQuery = """
                    INSERT INTO \(tableName) (
                    \(DatabaseConstants.columnUrl),
                    \(DatabaseConstants.columnPostData),
                    \(DatabaseConstants.columnMethod),
                    \(DatabaseConstants.columnLastProcessedAt),
                    \(DatabaseConstants.columnStatus)
                    ) VALUES (?, ?, ?, \(getCurrentTimestamp()), 'not_processed')
                    """
        let values: [Any] = [
            request.url,
            request.payload?.description ?? "",
            request.method
        ]
        
        databaseQueue?.inDatabase {database in
            do {
                try database.executeUpdate(insertQuery, values: values)
                print("Insert request to SQLite successful")
            } catch {
                print("Error inserting data: \(error.localizedDescription)")
            }
        }
    }

    func deleteRequestByID(id: Int?, tableName: String) {
        guard let id = id, id != 0 else {
            return
        }
        
        let query = "DELETE FROM \(tableName) WHERE id = ?"
        
        databaseQueue?.inDatabase {database in
            do {
                try database.executeUpdate(query, values: [id])
                print("Delete request from SQLite successful")
            } catch {
                print("Error deleting data - \(error)")
            }
        }
    }
    
    func getNextRequest() -> [String: Any]? {
        var resultDict: [String: Any]? = nil
        
        let query = "SELECT * FROM \(DatabaseConstants.reqTableName) ORDER BY \(DatabaseConstants.columnId) ASC LIMIT 1"
        
        databaseQueue?.inDatabase { database in
            if let resultSet = database.executeQuery(query, withArgumentsIn: []) {
                if resultSet.next() {
                    resultDict = resultSet.resultDictionary as? [String: Any]
                }
                resultSet.close()
            } else {
                print("Failed to execute query: \(database.lastErrorMessage())")
            }
        }
        
        return resultDict
    }

    
    func getNextCBRequest() -> [String: Any]? {
        var resultDict: [String: Any]? = nil
        
        let query = "SELECT * FROM \(DatabaseConstants.cbTableName) WHERE \(DatabaseConstants.columnStatus) = ? ORDER BY \(DatabaseConstants.columnId) ASC LIMIT 1"
        let values: [Any] = ["not_processed"]
        
        databaseQueue?.inDatabase { database in
            if let resultSet = database.executeQuery(query, withArgumentsIn: values) {
                if resultSet.next() {
                    resultDict = resultSet.resultDictionary as? [String: Any]
                }
                resultSet.close()
            } else {
                print("Failed to execute query: \(database.lastErrorMessage())")
            }
        }
        
        return resultDict
    }

}


