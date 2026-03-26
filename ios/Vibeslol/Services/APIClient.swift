import Foundation

final class APIClient {
    static let shared = APIClient()
    private let baseURL: String
    private let decoder: JSONDecoder

    private init() {
        // Local development
        self.baseURL = "http://localhost:8000"
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Users

    func createAnonymousUser(deviceToken: String? = nil) async throws -> User {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/users/anonymous")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = deviceToken {
            let body = ["device_token": token]
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try decoder.decode(User.self, from: data)
    }

    func getUser(id: String) async throws -> User {
        let url = URL(string: "\(baseURL)/api/users/\(id)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response)
        return try decoder.decode(User.self, from: data)
    }

    // MARK: - Videos

    func fetchFeed(page: Int = 0, limit: Int = 20) async throws -> [Video] {
        let url = URL(string: "\(baseURL)/api/videos/feed?page=\(page)&limit=\(limit)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response)
        let videos = try decoder.decode([Video].self, from: data)
        // Fall back to bundled seed videos if API returns empty
        return videos.isEmpty ? Video.mockFeed : videos
    }

    func uploadVideo(fileURL: URL, caption: String?, authorId: String) async throws -> UploadResponse {
        let url = URL(string: "\(baseURL)/api/videos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // author_id field
        body.appendMultipart(name: "author_id", value: authorId, boundary: boundary)

        // caption field
        if let caption = caption {
            body.appendMultipart(name: "caption", value: caption, boundary: boundary)
        }

        // file field
        let videoData = try Data(contentsOf: fileURL)
        body.appendMultipartFile(name: "file", filename: "video.mp4", mimeType: "video/mp4", data: videoData, boundary: boundary)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try decoder.decode(UploadResponse.self, from: data)
    }

    // MARK: - Likes

    func likeVideo(id: String, userId: String) async throws -> LikeResponse {
        let url = URL(string: "\(baseURL)/api/videos/\(id)/like")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "user_id=\(userId)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try decoder.decode(LikeResponse.self, from: data)
    }

    // MARK: - Comments

    func fetchComments(videoId: String) async throws -> [Comment] {
        let url = URL(string: "\(baseURL)/api/videos/\(videoId)/comments")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response)
        return try decoder.decode([Comment].self, from: data)
    }

    func postComment(videoId: String, userId: String, text: String) async throws -> Comment {
        let url = URL(string: "\(baseURL)/api/videos/\(videoId)/comments")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["user_id": userId, "text": text]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try decoder.decode(Comment.self, from: data)
    }

    // MARK: - Follow

    func toggleFollow(userId: String, followerId: String) async throws -> FollowResponse {
        let url = URL(string: "\(baseURL)/api/users/\(userId)/follow")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "follower_id=\(followerId)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try decoder.decode(FollowResponse.self, from: data)
    }

    func checkIsFollowing(userId: String, followerId: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/users/\(userId)/is-following?follower_id=\(followerId)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response)
        let result = try decoder.decode([String: Bool].self, from: data)
        return result["following"] ?? false
    }

    // MARK: - User Videos

    func fetchUserVideos(userId: String, page: Int = 0) async throws -> [Video] {
        let url = URL(string: "\(baseURL)/api/users/\(userId)/videos?page=\(page)&limit=20")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response)
        return try decoder.decode([Video].self, from: data)
    }

    // MARK: - Following Feed

    func fetchFollowingFeed(userId: String, page: Int = 0, limit: Int = 20) async throws -> [Video] {
        let url = URL(string: "\(baseURL)/api/videos/following-feed?user_id=\(userId)&page=\(page)&limit=\(limit)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response)
        return try decoder.decode([Video].self, from: data)
    }

    // MARK: - Helpers

    private func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }
}

// MARK: - Response Types

struct UploadResponse: Codable {
    let id: String
    let videoURL: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case videoURL = "video_url"
        case createdAt = "created_at"
    }
}

struct LikeResponse: Codable {
    let liked: Bool
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case liked
        case likeCount = "like_count"
    }
}

struct FollowResponse: Codable {
    let following: Bool
    let followerCount: Int

    enum CodingKeys: String, CodingKey {
        case following
        case followerCount = "follower_count"
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error \(code)"
        }
    }
}

// MARK: - Multipart Helpers

private extension Data {
    mutating func appendMultipart(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(name: String, filename: String, mimeType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
