import Foundation
import UIKit
import SwiftyJSON
import FMDB

class RequestHandler {
    static let shared = RequestHandler() // Singleton instance
    
    // Create a background queue
    static let backgroundQueue = DispatchQueue.global(qos: .background)
    
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
        
        // Dispatch the task to the background queue
        RequestHandler.backgroundQueue.async {
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
        var shouldBreakOuterLoop = false
        
        outerLoop: do {
            while true {
                dispatchGroup.enter() // Enter the dispatch group before starting any asynchronous operation
                
                guard let resultDict = SQLHelper.shared.getNextRequest() else {
                    dispatchGroup.leave()
                    completion(.success(true))
                    break
                }
                
                guard
                    let url = resultDict[SQLHelper.DatabaseConstants.columnUrl] as? String,
                    let payloadStr = resultDict[SQLHelper.DatabaseConstants.columnPostData] as? String,
                    let method = resultDict[SQLHelper.DatabaseConstants.columnMethod] as? String,
                    let id = (resultDict[SQLHelper.DatabaseConstants.columnId] as? Int) ?? Int(resultDict[SQLHelper.DatabaseConstants.columnId] as? String ?? ""),
                    let lastProcessedTimeMillis = resultDict[SQLHelper.DatabaseConstants.columnLastProcessedAt] as? Int64,
                    let status = resultDict[SQLHelper.DatabaseConstants.columnStatus] as? String
                else {
                    print("Error in retrieving data from SQLite")
                    dispatchGroup.leave()
                    completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error in retrieving data from SQLite"])))
                    break
                }
                
                let currentTimeMillis = Int64((Date().timeIntervalSince1970 * 1000).rounded())
                let timeDifference = TimeInterval(currentTimeMillis - lastProcessedTimeMillis)
                
                if (caller != "PerformRequest" && timeDifference < 2000) || status == "processing" {
                    dispatchGroup.leave()
                    break outerLoop
                }
                
                SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: SQLHelper.DatabaseConstants.reqTableName, status: "processing")
                
                var payload: JSON? = nil
                if !payloadStr.isEmpty {
                    if let data = payloadStr.data(using: .utf8) {
                        do {
                            payload = try JSON(data: data)
                        } catch {
                            print("Error deserializing JSON: \(error.localizedDescription)")
                            dispatchGroup.leave()
                            completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON: \(error.localizedDescription)"])))
                            break outerLoop
                        }
                    }
                }
                
                let request = Request(url: url, payload: payload, method: method)
                self.handleRetries(for: request, withID: id) { result in
                    defer {
                        dispatchGroup.leave() // Leave the dispatch group when the async operation completes
                    }
                    
                    switch result {
                    case .failure(let error):
                        shouldBreakOuterLoop = true
                        completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])))
                    case .success(_):
                        print("Request successful for ID: \(id)")
                    }
                }
                
                dispatchGroup.wait() // Wait for the current operation to complete before proceeding
                
                if shouldBreakOuterLoop {
                    break outerLoop
                }
            }
        }
    }

    public func processCBRequests(caller: String? = "", completion: @escaping (Result<Bool, Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var shouldBreakOuterLoop = false

        outerLoop: do {
            while true {
                dispatchGroup.enter() // Enter dispatch group for the async operation
                
                guard let resultDict = SQLHelper.shared.getNextCBRequest() else {
                    dispatchGroup.leave()
                    completion(.success(true))
                    break
                }
                
                guard
                    let url = resultDict[SQLHelper.DatabaseConstants.columnUrl] as? String,
                    let payloadStr = resultDict[SQLHelper.DatabaseConstants.columnPostData] as? String,
                    let method = resultDict[SQLHelper.DatabaseConstants.columnMethod] as? String,
                    let id = (resultDict[SQLHelper.DatabaseConstants.columnId] as? Int) ?? Int(resultDict[SQLHelper.DatabaseConstants.columnId] as? String ?? ""),
                    let lastProcessedTimeMillis = resultDict[SQLHelper.DatabaseConstants.columnLastProcessedAt] as? Int64
                else {
                    print("Error in retrieving data from SQLite")
                    dispatchGroup.leave()
                    completion(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error in retrieving data from SQLite"])))
                    break
                }
                
                let currentTimeMillis = Int64((Date().timeIntervalSince1970 * 1000).rounded())
                let timeDifference = TimeInterval(currentTimeMillis - lastProcessedTimeMillis)
                
                if (caller != "PerformRequest" && timeDifference < 2000) {
                    print("Request skipped because it's processed recently.")
                    dispatchGroup.leave()
                    break outerLoop
                }
                
                // Update the status to processing
                SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: SQLHelper.DatabaseConstants.cbTableName, status: "processing")
                
                var payload: JSON? = nil
                if !payloadStr.isEmpty {
                    if let data = payloadStr.data(using: .utf8) {
                        do {
                            payload = try JSON(data: data)
                        } catch {
                            print("Error deserializing JSON: \(error.localizedDescription)")
                            dispatchGroup.leave()
                            continue
                        }
                    }
                }
                
                let request = Request(url: url, payload: payload, method: method)
                handleRetries(for: request, withID: id) { result in
                    defer {
                        dispatchGroup.leave() // Leave the dispatch group when the async operation is completed
                    }
                    
                    switch result {
                    case .success(_):
                        print("Request successful for ID: \(id)")
                    case .failure(let error):
                        print("Request failed for ID: \(id) with error: \(error.localizedDescription)")
                        shouldBreakOuterLoop = true
                        completion(.failure(error))
                    }
                }
                
                dispatchGroup.wait() // Wait until the current request is fully processed
                
                if shouldBreakOuterLoop {
                    break outerLoop
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
        
        // fetch JWT token if it is a create profile call
        if request.method == "POST" && request.url.hasSuffix("/profile") {
            JWTRequestHandler().getAndSetJWTToken(distinctID: (request.payload?["distinct_id"].string)!){ result in
                switch result {
                case .failure(let error):
                    completionHandler(false, error)
                case .success(_):
                    print("JWT Token set successfully")
                    
                    self.apiCall(url: url, request: request, id: id, completionHandler: completionHandler)
                }
            }
        } else {
            apiCall(url: url, request: request, id: id, completionHandler: completionHandler)
        }
    }
    
    private func apiCall(url:URL, request:Request, id:Int, completionHandler: @escaping (Bool, Error?) -> Void){
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
                    
                    // fetch JWT token if it is a merge profile call
                    if request.url.contains("/merge/") {
                        JWTRequestHandler().getAndSetJWTToken(distinctID: request.url.components(separatedBy: "/merge/").last!){ result in
                            switch result {
                            case .failure(let error):
                                completionHandler(false, error)
                                return
                            case .success(_):
                                print("JWT Token set successfully")
                                completionHandler(true, nil)
                                return
                            }
                        }
                    } else{
                        completionHandler(true, nil)
                    }
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
        guard let url = url, !url.isEmpty else {
            return false
        }

        return FynoConstants.CALLBACK_URLS.contains { url.contains($0) }
    }
}

