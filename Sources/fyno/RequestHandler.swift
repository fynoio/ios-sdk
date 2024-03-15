import Foundation
import UIKit
import SwiftyJSON
import FMDB

class RequestHandler {
    static let shared = RequestHandler() // Singleton instance
    
    static let TIMEOUT = 6000
    static let MAX_BACKOFF_DELAY:Int64 = 60000
    static let MAX_RETRIES = 3
    
    struct Request {
        let url: String
        let payload: JSON?
        let method: String
        
        init(url: String, payload: JSON?, method: String = "POST") {
            self.url = url
            self.payload = payload
            self.method = method
        }
    }
    
    func PerformRequest(url: String, method: String,payload: JSON? = nil, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        let request = Request(url: url, payload: payload, method: method)
        
        // Create a background queue
        let backgroundQueue = DispatchQueue.global(qos: .background)
        
        // Dispatch the task to the background queue
        backgroundQueue.async {
            if self.isCallBackRequest(url: url) {
                SQLHelper.shared.insertRequest(request: request, tableName: "callbacks")
                self.processCBRequests(caller: "PerformRequest") {result in
                    switch result{
                    case .failure(let error):
                        completionHandler(.failure(error))
                        return
                    case .success(let success):
                        completionHandler(.success(success))
                        return
                    }
                }
            } else {
                SQLHelper.shared.insertRequest(request: request, tableName: "requests")
                self.processRequests(caller: "PerformRequest") {result in
                    switch result{
                    case .failure(let error):
                        completionHandler(.failure(error))
                        return
                    case .success(let success):
                        completionHandler(.success(success))
                        return
                    }
                }
            }
        }
    }
    
    public func processRequests(caller: String? = "", completion: @escaping (Result<Bool, Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var requestCursor: FMResultSet? = nil
        
        defer {
            requestCursor?.close()
        }
        
        var shouldBreakOuterLoop = false
        
        outerLoop: do {
            while true {
                dispatchGroup.enter() // Enter the dispatch group before starting any asynchronous operation
                
                requestCursor = SQLHelper.shared.getNextRequest()
                
                if requestCursor?.next() == true {
                    guard let url = requestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnUrl),
                          let payloadStr = requestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnPostData),
                          let method = requestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnMethod),
                          let id = Int(requestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnId) ?? ""),
                          let status = requestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnStatus),
                          let lastProcessedTimeMillis = requestCursor?.long(forColumn: SQLHelper.DatabaseConstants.columnLastProcessedAt) else {
                        print("Error in retrieving data from SQLite")
                        completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error in retrieving data from SQLite"])))
                        break
                    }
                    
                    let timeDifference = TimeInterval((Date().timeIntervalSince1970 * 1000).rounded()) - Double(lastProcessedTimeMillis)
                    
                    if caller != "PerformRequest" && timeDifference < 2000  || status == "processing" {
                        break outerLoop
                    }
                    
                    SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: SQLHelper.DatabaseConstants.reqTableName, status: "processing")
                    
                    var payload: JSON?
                    if payloadStr != "" {
                        if let data = payloadStr.data(using: .utf8) {
                            do {
                                payload = try JSON(data: data)
                            } catch {
                                print("Error deserializing JSON: \(error.localizedDescription)")
                                completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON: \(error.localizedDescription)"])))
                                break outerLoop
                            }
                        }
                    }
                    
                    let request = Request(url: url, payload: payload, method: method)
                    self.handleRetries(for: request, withID: id) { result in
                        defer {
                            dispatchGroup.leave() // Leave the dispatch group when the asynchronous operation is completed
                        }
                        
                        switch result {
                        case .failure(let error):
                            shouldBreakOuterLoop = true
                            completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])))
                        case .success(_):
                            print("request successful")
                        }
                    }
                } else {
                    completion(.success(true))
                    break
                }
                
                dispatchGroup.wait() // Wait for the current iteration to finish before proceeding to the next one
                
                if shouldBreakOuterLoop {
                    break outerLoop
                }
            }
        }
    }

    public func processCBRequests(caller:String? = "", completion: @escaping (Result<Bool, Error>) -> Void) {
        var cbRequestCursor: FMResultSet? = nil
        
        defer {
            cbRequestCursor?.close()
        }
        
        do {
            while true {
                // Retrieve one request from SQLite database
                cbRequestCursor = SQLHelper.shared.getNextCBRequest()
                
                if cbRequestCursor?.next() == true {
                    guard let url = cbRequestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnUrl),
                          let payloadStr = cbRequestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnPostData),
                          let method = cbRequestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnMethod),
                          let id = Int(cbRequestCursor?.string(forColumn: SQLHelper.DatabaseConstants.columnId) ?? ""),
                          let lastProcessedTimeMillis = cbRequestCursor?.long(forColumn: SQLHelper.DatabaseConstants.columnLastProcessedAt) else {
                        print("Error in retrieving data from SQLite")
                        continue
                    }
                    
                    let timeDifference = TimeInterval((Date().timeIntervalSince1970 * 1000).rounded()) - Double(lastProcessedTimeMillis)
                    
                    if caller != "PerformRequest" && timeDifference < 2000 {
                        // Skip this record as the last update time is less than 2 seconds ago
                        continue
                    }
                    
                    SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: SQLHelper.DatabaseConstants.cbTableName, status: "processing")
                    
                    var payload: JSON?
                    if payloadStr != "" {
                        if let data = payloadStr.data(using: .utf8) {
                            do {
                                payload = try JSON(data: data)
                            } catch {
                                print("Error deserializing JSON: \(error.localizedDescription)")
                                continue
                            }
                        }
                    }
                    
                    let request = Request(url: url, payload: payload, method: method)
                    handleRetries(for:request,withID: id) {result in
                        switch result{
                        case .success(_):
                            print("request successful")
                        case .failure(_):
                            print("request failed")
                        }
                    }
                } else {
                    break
                }
            }
        }
    }
    
    private func calculateDelay(retryCount: Int) -> Int64 {
        return min(Int64(pow(4.0, Double(retryCount)) * 1000), RequestHandler.MAX_BACKOFF_DELAY)
    }
    
    private func handleRetries(for request: Request, withID id: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("request:", request)
        var retries = 0

        func retry() {
            guard retries < RequestHandler.MAX_RETRIES else {
                self.handleFailedRequest(request: request, id: id)
                completion(.failure(RequestError.failedWithResponseCode(-1)))
                return
            }
            
            doRequest(request: request, id: id) { result, error in
                if result {
                    self.handleSuccessResponse(request: request, id: id)
                    if error != nil {
                        completion(.failure(error!))
                        return
                    } else {
                        completion(.success(true))
                        return
                    }
                } else if error != nil {
                    print("Request failed \(retries), retrying...")
                    let delayMillis = self.calculateDelay(retryCount: retries)
                    usleep(useconds_t(delayMillis * 1000))
                    retries += 1
                    retry()
                }
            }
        }

        retry()
    }
    
    private func handleFailedRequest(request: Request, id: Int? = 0) {
        print("Max retries reached for request: \(request.url)")
        
        if isCallBackRequest(url: request.url) {
            SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: "callbacks", status: "not_processed")
        } else {
            SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: "requests", status: "not_processed")
        }
    }

    private func doRequest(request: Request, id: Int, completionHandler: @escaping (Bool, Error?) -> Void) {
        guard let url = URL(string: request.url) else {
            completionHandler(false, NSError(domain: "Invalid URL", code: -1, userInfo: nil))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(Bundle.main.bundleIdentifier!, forHTTPHeaderField: "x-fn-app-id")
        urlRequest.addValue(Utilities.getintegrationID(), forHTTPHeaderField: "integration")
        urlRequest.addValue(Utilities.getJWTToken(), forHTTPHeaderField: "verify_token")
        
        if let payload = request.payload {
            do {
                let jsonData = try payload.rawData()
                urlRequest.httpBody = jsonData
            } catch {
                completionHandler(false, error)
                return
            }
        }
        
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        let session = URLSession(configuration: .default)
        
        let task = session.dataTask(with: urlRequest) { data,response,error in
            defer {
                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
            
            if let error = error {
                print("error", error)
                completionHandler(false, error)
                return
            }
            
            if let responseData = data, let responseBody = String(data: responseData, encoding: .utf8) {
                print("Response Body:", responseBody)
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                
                switch statusCode {
                case 200..<300:
                    print("Response code: \(statusCode)")
                    completionHandler(true, nil)
                    return
                case 400..<500:
                    print("Request failed with response code: \(statusCode)")
                    if statusCode == 401 {
                        if let responseData = data,
                           let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                           let errorMessage = json["_message"] as? String {
                            if errorMessage == "jwt_expired" {
                                JWTRequestHandler().getAndSetJWTToken(distinctID: Utilities.getDistinctID()){ result in
                                    switch result {
                                    case .failure(let error):
                                        completionHandler(false, error)
                                    case .success(_):
                                        print("JWT Token set successfully")
                                        self.doRequest(request: request, id: id, completionHandler: completionHandler)
                                    }
                                }
                                return
                            }
                        } else {
                            completionHandler(true,  NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON"]))
                            return
                        }
                    }
                    if let responseData = data,
                       let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let errorMessage = json["_message"] as? String {
                        completionHandler(true, NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                        return
                    } else {
                        completionHandler(true,  NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON"]))
                        return
                    }
                default:
                    print("Request failed with response code: \(statusCode)")
                    completionHandler(false, RequestError.failedWithResponseCode(statusCode))
                    return
                }
            }
        }
        
        task.resume()
    }

    private func handleSuccessResponse(request: Request, id: Int) {
        if isCallBackRequest(url: request.url) {
            SQLHelper.shared.deleteRequestByID(id: id, tableName: "callbacks")
        } else {
            SQLHelper.shared.deleteRequestByID(id: id, tableName: "requests")
        }
    }
    
    enum RequestError: Error {
        case failedWithResponseCode(Int)
    }
    
    private func isCallBackRequest(url: String?) -> Bool {
        return !(url?.isEmpty ?? true) && (url?.contains(FynoConstants.PROD_CALLBACK) ?? false)
    }
}

