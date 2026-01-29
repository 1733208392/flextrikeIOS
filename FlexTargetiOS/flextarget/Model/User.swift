import Foundation

struct User: Codable, Identifiable {
    var id: String { userUUID }
    let userUUID: String
    var username: String?
    let mobile: String?
    var accessToken: String
    var refreshToken: String
    
    init(userUUID: String, username: String? = nil, mobile: String? = nil, accessToken: String, refreshToken: String) {
        self.userUUID = userUUID
        self.username = username
        self.mobile = mobile
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}