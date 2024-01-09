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
                    case .success(let success):
                        completionHandler(.success(success))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            } else {
                SQLHelper.shared.insertRequest(request: request, tableName: "requests")
                self.processRequests(caller: "PerformRequest") {result in
                    switch result{
                    case .success(let success):
                        completionHandler(.success(success))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            }
        }
    }
    
    public func processRequests(caller: String? = "", completion: @escaping (Result<Bool, Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var success = true
        var requestCursor: FMResultSet? = nil
        
        defer {
            requestCursor?.close()
        }
        
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
                            self.handleFailedRequest(request: request, id: id)
                            success = false
                            completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])))
                        case .success(_):
                            self.handleSuccessResponse(request: request, id: id)
                        }
                    }
                } else {
                    completion(.success(success))
                    break
                }
                
                dispatchGroup.wait() // Wait for the current iteration to finish before proceeding to the next one
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
                            self.handleSuccessResponse(request: request, id: id)
                        case .failure(_):
                            self.handleFailedRequest(request: request, id: id)
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
    
    private func performRequest(request: Request, id: Int, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        doRequest(request: request, id: id) { result, error in
            if let error = error {
                print("Request failed: \(error.localizedDescription)")
                completionHandler(.failure(error))
            } else {
                completionHandler(.success(result))
            }
        }
    }

    
    private func handleRetries(for request: Request, withID id: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("request:", request)
        var retries = 0

        func retry() {
            guard retries < RequestHandler.MAX_RETRIES else {
                completion(.failure(RequestError.failedWithResponseCode(-1)))
                return
            }

            performRequest(request: request, id: id) { result in
                switch result {
                case .success:
                    completion(.success(true))
                case .failure(_):
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
        
        if Utilities.isFynoInitialized() {
            urlRequest.addValue("Bearer " + Utilities.getapi_key(), forHTTPHeaderField: "Authorization")
        }
        
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
                case 200..<300, 400..<500:
                    print("Response code: \(statusCode)")
                    completionHandler(true, nil)
                default:
                    print("Request failed with response code: \(statusCode)")
                    completionHandler(false, RequestError.failedWithResponseCode(statusCode))
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
        return !(url?.isEmpty ?? true) && (url?.contains("callback.fyno.io") ?? false)
    }
}

