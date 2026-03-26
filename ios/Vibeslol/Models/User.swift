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

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case videoCount = "video_count"
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
    }

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
