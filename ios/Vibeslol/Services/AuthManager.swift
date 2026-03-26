import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isReady = false

    private let keychain = KeychainService.shared

    var userId: String? { keychain.userId }
    var isLoggedIn: Bool { keychain.isLoggedIn }

    private init() {}

    /// Called once on app launch. Restores existing session or creates anonymous account.
    func bootstrap() async {
        if let existingId = keychain.userId {
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
            // First launch — generate device token and create anonymous account
            let deviceToken = UUID().uuidString
            keychain.deviceToken = deviceToken

            do {
                let user = try await APIClient.shared.createAnonymousUser(deviceToken: deviceToken)
                keychain.userId = user.id
                keychain.username = user.username
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
}
