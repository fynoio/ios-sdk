//
//  File.swift
//  
//
//  Created by Khush Chandawat on 10/04/23.
//

import Foundation

 

public class Payload {
    let distinctID: String
    let name: String
    let status: Int
    let sms: String
    let pushToken: String
    let pushIntegrationID: String
    private let token_prefix = "apns_token:"
    

    init(distinctID: String, name: String, status: Int, sms: String? = "", pushToken: String, pushIntegrationID: String) {
        self.distinctID = distinctID
        self.name = name
        self.status = status
        self.sms = sms ?? ""
        self.pushToken = token_prefix+pushToken
        self.pushIntegrationID = pushIntegrationID
       
    }
}


