import Foundation
import UIKit

class JWTRequestHandler {
    struct JWTRequest {
        let url: String
        let method: String
        
        init(url: String) {
            self.url = url
            self.method = "GET"
        }
    }
    
    func getAndSetJWTToken(
        distinctID: String,
        completionHandler: @escaping (Result<Bool, Error>) -> Void
    ) {
        // Build request URL
        let request = JWTRequest(url: "\(FynoConstants.PROD_ENDPOINT)/\(Utilities.getWSID())/\(distinctID)/token")
        guard let url = URL(string: request.url) else {
            completionHandler(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        // Begin background task on the main thread
        var backgroundTaskTemp: UIBackgroundTaskIdentifier = .invalid
        DispatchQueue.main.sync {
            backgroundTaskTemp = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        }
        let backgroundTaskID = backgroundTaskTemp // immutable copy to avoid data race
        
        let session = URLSession(configuration: .default)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        
        // Perform the network call
        let task = session.dataTask(with: urlRequest) { data, response, error in
            defer {
                // End background task on the main thread
                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
            
            // Handle network error
            if let error = error {
                print("error", error)
                completionHandler(.failure(error))
                return
            }
            
            // Log raw response body
            if let responseData = data,
               let responseBody = String(data: responseData, encoding: .utf8) {
                print("Response Body:", responseBody)
            }
            
            // Handle HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                
                switch statusCode {
                case 200..<300:
                    print("Response code: \(statusCode)")
                    
                    if let responseData = data,
                       let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let jwtToken = json["token"] as? String {
                        
                        // Set JWT token on the main thread if Utilities is @MainActor
                        DispatchQueue.main.async {
                            Utilities.setJWTToken(jwtToken: jwtToken)
                        }
                    }
                    completionHandler(.success(true))
                    
                case 400..<500:
                    print("Request failed with response code: \(statusCode)")
                    
                    if let responseData = data,
                       let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let errorMessage = json["_message"] as? String {
                        
                        completionHandler(.failure(
                            NSError(domain: "FynoSDK", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        ))
                    } else {
                        completionHandler(.failure(
                            NSError(domain: "FynoSDK", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON"])
                        ))
                    }
                    
                default:
                    print("Request failed with response code: \(statusCode)")
                    completionHandler(.failure(RequestError.failedWithResponseCode(statusCode)))
                }
            }
        }
        
        task.resume()
    }


    enum RequestError: Error {
        case failedWithResponseCode(Int)
    }
}
