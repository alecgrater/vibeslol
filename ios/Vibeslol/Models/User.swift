import Foundation

struct User: Identifiable, Codable {
    let id: String
    let username: String
    let displayName: String?
    let avatarURL: String?
    let bio: String?
    let followerCount: Int
    let followingCount: Int
    let videoCount: Int
    let isAnonymous: Bool
    let createdAt: Date

    static var anonymous: User {
        User(
            id: UUID().uuidString,
            username: "vibe_\(String(Int.random(in: 1000...9999)))",
            displayName: nil,
            avatarURL: nil,
            bio: nil,
            followerCount: 0,
            followingCount: 0,
            videoCount: 0,
            isAnonymous: true,
            createdAt: Date()
        )
    }
}
