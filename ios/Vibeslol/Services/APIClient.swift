import Foundation

final class APIClient {
    static let shared = APIClient()
    private let baseURL: String
    private let decoder: JSONDecoder

    /// Serial queue to prevent concurrent token refreshes
    private let refreshLock = NSLock()
    private var isRefreshing = false

    private init() {
        #if DEBUG
        self.baseURL = "http://localhost:8000"
        #else
        self.baseURL = "https://vibeslol-production.up.railway.app"
        #endif
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Auth (no Bearer token needed)

    func createAnonymousAuth(deviceToken: String? = nil) async throws -> AuthTokenResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/auth/anonymous")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = deviceToken {
            let body = ["device_token": token]
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try decoder.decode(AuthTokenResponse.self, from: data)
    }

    func refreshTokens(refreshToken: String) async throws -> AuthTokenResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/auth/refresh")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try decoder.decode(AuthTokenResponse.self, from: data)
    }

    // MARK: - Users

    func getUser(id: String) async throws -> User {
        let url = URL(string: "\(baseURL)/api/users/\(id)")!
        let (data, response) = try await authenticatedData(from: url)
        try checkResponse(response)
        return try decoder.decode(User.self, from: data)
    }

    // MARK: - Videos

    func fetchFeed(page: Int = 0, limit: Int = 20) async throws -> [Video] {
        let urlString = "\(baseURL)/api/videos/feed?page=\(page)&limit=\(limit)"
        let url = URL(string: urlString)!
        let (data, response) = try await authenticatedData(from: url)
        try checkResponse(response)
        let videos = try decoder.decode([Video].self, from: data)
        return videos.isEmpty ? Video.mockFeed : videos
    }

    func uploadVideo(fileURL: URL, caption: String?) async throws -> UploadResponse {
        let url = URL(string: "\(baseURL)/api/videos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        if let caption = caption {
            body.appendMultipart(name: "caption", value: caption, boundary: boundary)
        }

        let videoData = try Data(contentsOf: fileURL)
        body.appendMultipartFile(name: "file", filename: "video.mp4", mimeType: "video/mp4", data: videoData, boundary: boundary)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        let (data, response) = try await authenticatedData(for: request)
        try checkResponse(response)
        return try decoder.decode(UploadResponse.self, from: data)
    }

    // MARK: - Likes

    func likeVideo(id: String) async throws -> LikeResponse {
        let url = URL(string: "\(baseURL)/api/videos/\(id)/like")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await authenticatedData(for: request)
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

    func postComment(videoId: String, text: String) async throws -> Comment {
        let url = URL(string: "\(baseURL)/api/videos/\(videoId)/comments")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["text": text]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await authenticatedData(for: request)
        try checkResponse(response)
        return try decoder.decode(Comment.self, from: data)
    }

    // MARK: - Follow

    func toggleFollow(userId: String) async throws -> FollowResponse {
        let url = URL(string: "\(baseURL)/api/users/\(userId)/follow")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await authenticatedData(for: request)
        try checkResponse(response)
        return try decoder.decode(FollowResponse.self, from: data)
    }

    func checkIsFollowing(userId: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/users/\(userId)/is-following")!
        let (data, response) = try await authenticatedData(from: url)
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

    func fetchFollowingFeed(page: Int = 0, limit: Int = 20) async throws -> [Video] {
        let url = URL(string: "\(baseURL)/api/videos/following-feed?page=\(page)&limit=\(limit)")!
        let (data, response) = try await authenticatedData(from: url)
        try checkResponse(response)
        return try decoder.decode([Video].self, from: data)
    }

    // MARK: - Analytics

    func trackWatchEvent(
        videoId: String,
        watchDurationMs: Int,
        loopCount: Int,
        skipped: Bool,
        watchPercentage: Double
    ) async throws {
        let url = URL(string: "\(baseURL)/api/analytics/watch")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "video_id": videoId,
            "watch_duration_ms": watchDurationMs,
            "loop_count": loopCount,
            "skipped": skipped,
            "watch_percentage": watchPercentage
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await authenticatedData(for: request)
        try checkResponse(response)
    }

    // MARK: - Report

    func reportVideo(videoId: String, reason: String, details: String? = nil) async throws -> ReportResponse {
        let url = URL(string: "\(baseURL)/api/videos/\(videoId)/report")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = ["reason": reason]
        if let details = details {
            body["details"] = details
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await authenticatedData(for: request)
        try checkResponse(response)
        return try decoder.decode(ReportResponse.self, from: data)
    }

    // MARK: - Block

    func toggleBlock(userId: String) async throws -> BlockResponse {
        let url = URL(string: "\(baseURL)/api/users/\(userId)/block")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await authenticatedData(for: request)
        try checkResponse(response)
        return try decoder.decode(BlockResponse.self, from: data)
    }

    // MARK: - Authenticated Request Helpers

    /// Perform a GET request with Bearer auth and 401→refresh→retry.
    private func authenticatedData(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        return try await authenticatedData(for: request)
    }

    /// Perform an arbitrary request with Bearer auth and 401→refresh→retry.
    private func authenticatedData(for request: URLRequest) async throws -> (Data, URLResponse) {
        var req = request

        // Attach access token if available
        if let token = KeychainService.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        // If 401, try refreshing tokens once
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let refreshed = await refreshOnce()
            if refreshed {
                // Retry with new token
                var retryReq = request
                if let newToken = KeychainService.shared.accessToken {
                    retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                return try await URLSession.shared.data(for: retryReq)
            }
        }

        return (data, response)
    }

    /// Ensure only one refresh happens at a time.
    private func refreshOnce() async -> Bool {
        refreshLock.lock()
        if isRefreshing {
            refreshLock.unlock()
            // Wait briefly for the other refresh to complete
            try? await Task.sleep(nanoseconds: 500_000_000)
            return KeychainService.shared.accessToken != nil
        }
        isRefreshing = true
        refreshLock.unlock()

        let success = await AuthManager.shared.refreshTokens()

        refreshLock.lock()
        isRefreshing = false
        refreshLock.unlock()

        return success
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

struct AuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let userId: String
    let username: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case userId = "user_id"
        case username
    }
}

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

struct ReportResponse: Codable {
    let id: Int
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case createdAt = "created_at"
    }
}

struct BlockResponse: Codable {
    let blocked: Bool
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
