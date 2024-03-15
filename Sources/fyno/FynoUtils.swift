import Foundation

class FynoUtils {
    func getEndpoint(event: String, env: String? = "live", profile: String? = nil, newId: String? = nil) -> String {
        let baseEndpoint = (env == "test") ? FynoConstants.DEV_ENDPOINT : FynoConstants.PROD_ENDPOINT
        let version = Utilities.getVersion() ?? "live"
        let commonPath = "\(Utilities.getWSID())/track/\(version)/\(FynoConstants.PROFILE)"
        
        switch event {
        case "create_profile":
            return "\(baseEndpoint)/\(commonPath)"
        case "get_profile":
            return "\(baseEndpoint)/\(commonPath)/\(profile ?? "")"
        case "merge_profile":
            return "\(baseEndpoint)/\(commonPath)/\(profile ?? "")/merge/\(newId ?? "")"
        case "upsert_profile":
            return "\(baseEndpoint)/\(commonPath)/\(profile ?? "")"
        case "update_channel":
            return "\(baseEndpoint)/\(commonPath)/\(profile ?? "")/channel"
        case "delete_channel":
            return "\(baseEndpoint)/\(commonPath)/\(profile ?? "")/channel/delete"
        case "event_trigger":
            return "\(baseEndpoint)/\(Utilities.getWSID())/\(version)/\(FynoConstants.EVENT_PATH)"
        default:
            return ""
        }
    }
}

struct FynoConstants {
    static let DEV_ENDPOINT = "https://api.dev.fyno.io/v2"
    static let PROD_ENDPOINT = "https://api.fyno.io/v2"
    static let PROFILE = "profile"
    static let EVENT_PATH = "event"
    static let DEV_CALLBACK = "callback.dev.fyno.io"
    static let PROD_CALLBACK = "callback.fyno.io"
}
