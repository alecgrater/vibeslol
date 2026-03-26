import Foundation

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var videos: [Video] = []
    @Published var isFollowing = false
    @Published var isLoading = true

    let userId: String

    init(userId: String) {
        self.userId = userId
    }

    func load() {
        Task {
            isLoading = true
            async let userTask = APIClient.shared.getUser(id: userId)
            async let videosTask = APIClient.shared.fetchUserVideos(userId: userId)

            do {
                let fetchedUser = try await userTask
                user = fetchedUser
            } catch {
                print("[profile] Failed to load user: \(error.localizedDescription)")
            }

            do {
                videos = try await videosTask
            } catch {
                print("[profile] Failed to load videos: \(error.localizedDescription)")
            }

            // Check follow status
            if let myId = AuthManager.shared.userId, myId != userId {
                do {
                    isFollowing = try await APIClient.shared.checkIsFollowing(userId: userId, followerId: myId)
                } catch {
                    print("[profile] Failed to check follow status: \(error.localizedDescription)")
                }
            }

            isLoading = false
        }
    }

    func toggleFollow() {
        guard let myId = AuthManager.shared.userId, myId != userId else { return }

        let wasFollowing = isFollowing
        isFollowing = !wasFollowing

        // Optimistic follower count update
        if var u = user {
            let newCount = wasFollowing ? max(0, u.followerCount - 1) : u.followerCount + 1
            user = User(
                id: u.id, username: u.username, displayName: u.displayName,
                avatarURL: u.avatarURL, bio: u.bio,
                followerCount: newCount, followingCount: u.followingCount,
                videoCount: u.videoCount, isAnonymous: u.isAnonymous, createdAt: u.createdAt
            )
        }

        HapticsService.shared.mediumTap()

        Task {
            do {
                let result = try await APIClient.shared.toggleFollow(userId: userId, followerId: myId)
                isFollowing = result.following
                if var u = user {
                    user = User(
                        id: u.id, username: u.username, displayName: u.displayName,
                        avatarURL: u.avatarURL, bio: u.bio,
                        followerCount: result.followerCount, followingCount: u.followingCount,
                        videoCount: u.videoCount, isAnonymous: u.isAnonymous, createdAt: u.createdAt
                    )
                }
            } catch {
                // Revert
                isFollowing = wasFollowing
                print("[profile] Follow API error: \(error.localizedDescription)")
            }
        }
    }
}
