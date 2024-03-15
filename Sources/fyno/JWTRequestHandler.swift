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
    
    func getAndSetJWTToken(distinctID:String,  completionHandler: @escaping (Result<Bool, Error>) -> Void){
        let request = JWTRequest(url: "\(FynoConstants.PROD_ENDPOINT)/\(Utilities.getWSID())/\(Utilities.getDistinctID())/token")
        guard let url = URL(string: request.url) else {
            completionHandler(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        let session = URLSession(configuration: .default)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        
        let task = session.dataTask(with: urlRequest) { data,response,error in
            defer {
                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
            
            if let error = error {
                print("error", error)
                completionHandler(.failure(error))
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
                    if let responseData = data,
                       let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let jwtToken = json["token"] as? String {
                        // Set JWT token in preferences
                        Utilities.setJWTToken(jwtToken: jwtToken)
                    }
                    completionHandler(.success(true))
                    return
                case 400..<500:
                    print("Request failed with response code: \(statusCode)")
                    if let responseData = data,
                       let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                       let errorMessage = json["_message"] as? String {
                        completionHandler(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                        return
                    } else {
                        completionHandler(.failure(NSError(domain: "FynoSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error deserializing JSON"])))
                        return
                    }
                default:
                    print("Request failed with response code: \(statusCode)")
                    completionHandler(.failure(RequestError.failedWithResponseCode(statusCode)))
                    return
                }
            }
        }
        
        task.resume()
    }
    
    enum RequestError: Error {
        case failedWithResponseCode(Int)
    }
}
