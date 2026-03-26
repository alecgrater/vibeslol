import Foundation

final class APIClient {
    static let shared = APIClient()
    private let baseURL: String

    private init() {
        // Local development
        self.baseURL = "http://localhost:8000"
    }

    func fetchFeed(page: Int = 0, limit: Int = 20) async throws -> [Video] {
        // TODO: Implement when API is ready
        return Video.mockFeed
    }

    func likeVideo(id: String) async throws {
        // TODO: POST /api/videos/{id}/like
    }

    func createAnonymousUser() async throws -> User {
        // TODO: POST /api/users/anonymous
        return User.anonymous
    }
}
