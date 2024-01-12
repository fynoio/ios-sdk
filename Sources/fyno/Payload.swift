import Foundation

public class Payload {
    let distinctID: String?
    let status: Int?
    var pushToken:String?
    let integrationId:String?
    let name:String?

    init(distinctID: String? = "", status: Int? = 1, pushToken: String? = "", integrationId: String? = "", name:String? = "") {
        self.distinctID = distinctID
        self.status = status
        self.pushToken = pushToken
        self.integrationId = integrationId
        self.name = name
    }
}
