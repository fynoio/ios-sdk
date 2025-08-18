import Foundation
import UIKit
@preconcurrency import SwiftyJSON
import FMDB

final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// MARK: - RequestHandler
/// Handles queued requests with retry and exponential backoff.
final class RequestHandler: @unchecked Sendable {
    
    // Singleton instance (unsafe nonisolated is fine for static, immutable access)
    static let shared = RequestHandler()
    
    // Background execution queue
    static let backgroundQueue = DispatchQueue.global(qos: .background)
    
    // Config
    static let TIMEOUT: Int = 6000
    static let MAX_BACKOFF_DELAY: Int64 = 60_000 // ms
    static let MAX_RETRIES: Int = 3
    
    // MARK: - Types
    struct Request: @unchecked Sendable {
        let url: String
        let payload: JSON?
        let method: String
        
        init(url: String, payload: JSON?, method: String = "POST") {
            self.url = url
            self.payload = payload
            self.method = method
        }
    }
    
    enum RequestError: Error {
        case failedWithResponseCode(Int)
        case invalidURL
        case jsonDeserialization
    }
    
    // MARK: - Public API
    
    func PerformRequest(
        url: String,
        method: String,
        payload: JSON? = nil,
        completionHandler: @Sendable @escaping (Result<Bool, Error>) -> Void
    ) {
        let request = Request(url: url, payload: payload, method: method)
        
        RequestHandler.backgroundQueue.async { [self] in
            if self.isCallBackRequest(url: url) {
                SQLHelper.shared.insertRequest(request: request, tableName: SQLHelper.DatabaseConstants.cbTableName)
                self.processCBRequests(caller: "PerformRequest") { result in
                    DispatchQueue.main.async { completionHandler(result) }
                }
            } else {
                SQLHelper.shared.insertRequest(request: request, tableName: SQLHelper.DatabaseConstants.reqTableName)
                self.processRequests(caller: "PerformRequest") { result in
                    DispatchQueue.main.async { completionHandler(result) }
                }
            }
        }
    }
    
    // MARK: - Queued Processing
    
    public func processRequests(
        caller: String? = "",
        completion: @Sendable @escaping (Result<Bool, Error>) -> Void
    ) {
        let dispatchGroup = DispatchGroup()
        let stateQueue = DispatchQueue(label: "com.fyno.processRequests.state")
        
        outerLoop: while true {
            dispatchGroup.enter()
            
            guard let resultDict = SQLHelper.shared.getNextRequest() else {
                dispatchGroup.leave()
                DispatchQueue.main.async { completion(.success(true)) }
                break
            }
            
            guard
                let url = resultDict[SQLHelper.DatabaseConstants.columnUrl] as? String,
                let payloadStr = resultDict[SQLHelper.DatabaseConstants.columnPostData] as? String,
                let method = resultDict[SQLHelper.DatabaseConstants.columnMethod] as? String,
                let id = (resultDict[SQLHelper.DatabaseConstants.columnId] as? Int)
                    ?? Int(resultDict[SQLHelper.DatabaseConstants.columnId] as? String ?? ""),
                let lastProcessedTimeMillis = resultDict[SQLHelper.DatabaseConstants.columnLastProcessedAt] as? Int64,
                let status = resultDict[SQLHelper.DatabaseConstants.columnStatus] as? String
            else {
                dispatchGroup.leave()
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "FynoSDK",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Error in retrieving data from SQLite"]
                    )))
                }
                break
            }
            
            let currentTimeMillis = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            let timeDifference = TimeInterval(currentTimeMillis - lastProcessedTimeMillis)
            
            if (caller != "PerformRequest" && timeDifference < 2000) || status == "processing" {
                dispatchGroup.leave()
                break outerLoop
            }
            
            SQLHelper.shared.updateStatusAndLastProcessedTime(
                id: id,
                tableName: SQLHelper.DatabaseConstants.reqTableName,
                status: "processing"
            )
            
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
            
            // This will be updated inside the closure in a thread-safe manner
            var requestFailed = false
            
            self.handleRetries(for: request, withID: id) { result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .failure(let error):
                    stateQueue.sync { requestFailed = true }
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "FynoSDK",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
                        )))
                    }
                case .success:
                    break
                }
            }
            
            // Wait until the closure has finished
            dispatchGroup.wait()
            
            if stateQueue.sync(execute: { requestFailed }) {
                break outerLoop
            }
        }
    }
    
    public func processCBRequests(
        caller: String? = "",
        completion: @Sendable @escaping (Result<Bool, Error>) -> Void
    ) {
        let dispatchGroup = DispatchGroup()
        
        outerLoop: while true {
            dispatchGroup.enter()
            
            guard let resultDict = SQLHelper.shared.getNextCBRequest() else {
                dispatchGroup.leave()
                DispatchQueue.main.async { completion(.success(true)) }
                break
            }
            
            guard
                let url = resultDict[SQLHelper.DatabaseConstants.columnUrl] as? String,
                let payloadStr = resultDict[SQLHelper.DatabaseConstants.columnPostData] as? String,
                let method = resultDict[SQLHelper.DatabaseConstants.columnMethod] as? String,
                let id = (resultDict[SQLHelper.DatabaseConstants.columnId] as? Int)
                    ?? Int(resultDict[SQLHelper.DatabaseConstants.columnId] as? String ?? ""),
                let lastProcessedTimeMillis = resultDict[SQLHelper.DatabaseConstants.columnLastProcessedAt] as? Int64
            else {
                dispatchGroup.leave()
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "FynoSDK",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Error in retrieving data from SQLite"]
                    )))
                }
                break
            }
            
            let currentTimeMillis = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            let timeDifference = TimeInterval(currentTimeMillis - lastProcessedTimeMillis)
            
            if caller != "PerformRequest" && timeDifference < 2000 {
                // processed recently, skip
                dispatchGroup.leave()
                break outerLoop
            }
            
            SQLHelper.shared.updateStatusAndLastProcessedTime(
                id: id,
                tableName: SQLHelper.DatabaseConstants.cbTableName,
                status: "processing"
            )
            
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
            
            let errorBox = Box<Error?>(nil)
            
            self.handleRetries(for: request, withID: id) { result in
                defer { dispatchGroup.leave() }
                if case .failure(let error) = result {
                    errorBox.value = error
                }
            }
            
            dispatchGroup.wait()
            
            if let error = errorBox.value {
                DispatchQueue.main.async { completion(.failure(error)) }
                break outerLoop
            }
        }
    }
    
    // MARK: - Retry Logic
    
    private func calculateDelay(retryCount: Int) -> Int64 {
        // Exponential backoff: 1s, 4s, 16s ... capped
        return min(Int64(pow(4.0, Double(retryCount)) * 1000.0), RequestHandler.MAX_BACKOFF_DELAY)
    }
    
    private func handleRetries(
        for request: Request,
        withID id: Int,
        completion: @Sendable @escaping (Result<Bool, Error>) -> Void
    ) {
        @Sendable
        func attempt(retries: Int) {
            self.doRequest(request: request, id: id) { success, error in
                if success {
                    self.handleSuccessResponse(request: request, id: id)
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(true))
                    }
                    return
                }
                
                if retries >= RequestHandler.MAX_RETRIES - 1 {
                    self.handleFailedRequest(request: request, id: id)
                    completion(.failure(RequestError.failedWithResponseCode(-1)))
                    return
                }
                
                let delayMillis = self.calculateDelay(retryCount: retries + 1)
                RequestHandler.backgroundQueue.asyncAfter(
                    deadline: .now() + .milliseconds(Int(delayMillis))
                ) {
                    attempt(retries: retries + 1)
                }
            }
        }
        
        attempt(retries: 0)
    }
    
    
    private func handleFailedRequest(request: Request, id: Int) {
        print("Max retries reached for request: \(request.url)")
        if isCallBackRequest(url: request.url) {
            SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: SQLHelper.DatabaseConstants.cbTableName, status: "not_processed")
        } else {
            SQLHelper.shared.updateStatusAndLastProcessedTime(id: id, tableName: SQLHelper.DatabaseConstants.reqTableName, status: "not_processed")
        }
    }
    
    // MARK: - Networking
    
    private func doRequest(
        request: Request,
        id: Int,
        completionHandler: @Sendable @escaping (Bool, Error?) -> Void
    ) {
        guard let url = URL(string: request.url) else {
            completionHandler(false, RequestError.invalidURL)
            return
        }
        
        // fetch JWT token if it is a create profile call
        if request.method == "POST" && request.url.hasSuffix("/profile") {
            let distinctID = extractDistinctID(from: request.payload)
            JWTRequestHandler().getAndSetJWTToken(distinctID: distinctID) { result in
                switch result {
                case .failure(let error):
                    completionHandler(false, error)
                case .success:
                    self.apiCall(url: url, request: request, id: id, completionHandler: completionHandler)
                }
            }
        } else {
            apiCall(url: url, request: request, id: id, completionHandler: completionHandler)
        }
    }
    
    private func apiCall(
        url: URL,
        request: Request,
        id: Int,
        completionHandler: @Sendable @escaping (Bool, Error?) -> Void
    ) {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(Bundle.main.bundleIdentifier ?? "unknown", forHTTPHeaderField: "x-fn-app-id")
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
        
        let backgroundTaskID: UIBackgroundTaskIdentifier = DispatchQueue.main.sync {
            UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        }
        
        let sessionConfig = URLSessionConfiguration.default
        // Optionally apply timeout if desired (TIMEOUT is ms)
        sessionConfig.timeoutIntervalForRequest = TimeInterval(RequestHandler.TIMEOUT) / 1000.0
        sessionConfig.timeoutIntervalForResource = TimeInterval(RequestHandler.TIMEOUT) / 1000.0
        let session = URLSession(configuration: sessionConfig)
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
            
            if let error = error {
                completionHandler(false, error)
                return
            }
            
            if let responseData = data, let responseBody = String(data: responseData, encoding: .utf8) {
                print("Response Body:", responseBody)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(false, RequestError.failedWithResponseCode(-1))
                return
            }
            
            let statusCode = httpResponse.statusCode
            switch statusCode {
            case 200..<300:
                // Success
                if request.url.contains("/merge/") {
                    // Refresh token for the merged profile
                    let distinct = request.url.components(separatedBy: "/merge/").last ?? Utilities.getDistinctID()
                    JWTRequestHandler().getAndSetJWTToken(distinctID: distinct) { result in
                        switch result {
                        case .failure(let error):
                            completionHandler(false, error)
                        case .success:
                            completionHandler(true, nil)
                        }
                    }
                } else {
                    completionHandler(true, nil)
                }
                
            case 400..<500:
                if statusCode == 401 {
                    // Attempt automatic JWT refresh on jwt_expired
                    if let responseData = data,
                       let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let errorMessage = json["_message"] as? String,
                       errorMessage == "jwt_expired" {
                        
                        JWTRequestHandler().getAndSetJWTToken(distinctID: Utilities.getDistinctID()) { result in
                            switch result {
                            case .failure(let error):
                                completionHandler(false, error)
                            case .success:
                                // retry once immediately after refreshing token
                                self.doRequest(request: request, id: id, completionHandler: completionHandler)
                            }
                        }
                        return
                    } else {
                        completionHandler(true, NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON"]))
                        return
                    }
                }
                
                if let responseData = data,
                   let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                   let errorMessage = json["_message"] as? String {
                    completionHandler(true, NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                } else {
                    completionHandler(true, NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON"]))
                }
                
            default:
                completionHandler(false, RequestError.failedWithResponseCode(statusCode))
            }
        }
        
        task.resume()
    }
    
    private func handleSuccessResponse(request: Request, id: Int) {
        if isCallBackRequest(url: request.url) {
            SQLHelper.shared.deleteRequestByID(id: id, tableName: SQLHelper.DatabaseConstants.cbTableName)
        } else {
            SQLHelper.shared.deleteRequestByID(id: id, tableName: SQLHelper.DatabaseConstants.reqTableName)
        }
    }
    
    // MARK: - Helpers
    
    private func isCallBackRequest(url: String?) -> Bool {
        guard let url = url, !url.isEmpty else { return false }
        return FynoConstants.CALLBACK_URLS.contains { url.contains($0) }
    }
    
    /// Extracts "distinct_id" from a JSON-encoded payload Data (if present).
    private func extractDistinctID(from payload: JSON?) -> String {
        guard let payload = payload else {
            print("No payload data provided")
            return Utilities.getDistinctID()
        }
        
        if let id = payload["distinct_id"].string, !id.isEmpty {
            return id
        } else {
            print("'distinct_id' key missing or not a String in JSON:", payload)
        }
        
        let fallbackID = Utilities.getDistinctID()
        print("Returning fallback distinct ID:", fallbackID)
        return fallbackID
    }
}
