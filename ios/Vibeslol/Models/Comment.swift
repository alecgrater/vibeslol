import Foundation

struct Comment: Identifiable, Codable {
    let id: Int
    let userId: String
    let username: String
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, username, text
        case userId = "user_id"
        case createdAt = "created_at"
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}
