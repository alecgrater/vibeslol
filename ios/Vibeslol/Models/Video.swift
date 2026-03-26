import Foundation

struct Video: Identifiable, Codable {
    let id: String
    let username: String
    let caption: String?
    let videoURL: String
    let thumbnailURL: String?
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let loopCount: Int
    let createdAt: Date

    /// Returns a file URL for a bundled video, or a remote URL
    var resolvedURL: URL? {
        // Check if it's a bundle resource name (e.g. "video1")
        if !videoURL.contains("/"), let bundleURL = Bundle.main.url(forResource: videoURL, withExtension: "mp4") {
            return bundleURL
        }
        return URL(string: videoURL)
    }

    static var mock: Video {
        Video(
            id: UUID().uuidString,
            username: "vibeslol",
            caption: "welcome to the chaos",
            videoURL: "video1",
            thumbnailURL: nil,
            likeCount: 420,
            commentCount: 69,
            shareCount: 12,
            loopCount: 1337,
            createdAt: Date()
        )
    }

    // Bundled seed videos — generated with Python simulations
    static var mockFeed: [Video] {
        [
            Video(
                id: "1", username: "chaosqueen",
                caption: "balls multiply on every bounce",
                videoURL: "video1",
                thumbnailURL: nil, likeCount: 2400, commentCount: 89,
                shareCount: 45, loopCount: 5600, createdAt: Date()
            ),
            Video(
                id: "2", username: "vibechecker",
                caption: "particles go brrr",
                videoURL: "video2",
                thumbnailURL: nil, likeCount: 890, commentCount: 34,
                shareCount: 12, loopCount: 2100, createdAt: Date()
            ),
            Video(
                id: "3", username: "scroll_addict",
                caption: "hypnotic pulse rings",
                videoURL: "video3",
                thumbnailURL: nil, likeCount: 156, commentCount: 8,
                shareCount: 3, loopCount: 340, createdAt: Date()
            ),
            Video(
                id: "4", username: "neon_dreams",
                caption: "dna but make it aesthetic",
                videoURL: "video4",
                thumbnailURL: nil, likeCount: 5200, commentCount: 201,
                shareCount: 88, loopCount: 12000, createdAt: Date()
            ),
            Video(
                id: "5", username: "sixsecking",
                caption: "fractal tree grows in 6 seconds",
                videoURL: "video5",
                thumbnailURL: nil, likeCount: 1100, commentCount: 55,
                shareCount: 23, loopCount: 3400, createdAt: Date()
            ),
        ]
    }
}
