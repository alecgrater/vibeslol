import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isReady = false

    private let keychain = KeychainService.shared

    var userId: String? { keychain.userId }
    var isLoggedIn: Bool { keychain.isLoggedIn }
    var accessToken: String? { keychain.accessToken }

    private init() {}

    /// Called once on app launch. Restores existing session or creates anonymous account.
    func bootstrap() async {
        if let existingId = keychain.userId, keychain.accessToken != nil {
            // Try to refresh user from API
            do {
                let user = try await APIClient.shared.getUser(id: existingId)
                currentUser = user
            } catch {
                // API unreachable — build a local user from Keychain data
                print("[auth] API unreachable, using cached credentials")
                currentUser = User(
                    id: existingId,
                    username: keychain.username ?? "vibe_anon",
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
        } else {
            // First launch — generate device token and create anonymous account with JWT
            let deviceToken = UUID().uuidString
            keychain.deviceToken = deviceToken

            do {
                let authResponse = try await APIClient.shared.createAnonymousAuth(deviceToken: deviceToken)
                keychain.userId = authResponse.userId
                keychain.username = authResponse.username
                keychain.accessToken = authResponse.accessToken
                keychain.refreshToken = authResponse.refreshToken

                // Fetch full user profile
                let user = try await APIClient.shared.getUser(id: authResponse.userId)
                currentUser = user
            } catch {
                // API unreachable — create local-only anonymous user, will sync later
                print("[auth] API unreachable on first launch, creating local account")
                let localUser = User.anonymous
                keychain.userId = localUser.id
                keychain.username = localUser.username
                currentUser = localUser
            }
        }
        isReady = true
    }

    /// Refresh JWT tokens using the stored refresh token.
    func refreshTokens() async -> Bool {
        guard let refreshToken = keychain.refreshToken else { return false }
        do {
            let response = try await APIClient.shared.refreshTokens(refreshToken: refreshToken)
            keychain.accessToken = response.accessToken
            keychain.refreshToken = response.refreshToken
            return true
        } catch {
            print("[auth] Token refresh failed: \(error.localizedDescription)")
            return false
        }
    }
}
