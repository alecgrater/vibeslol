import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var currentIndex = 0
    @Published var likedVideoIds: Set<String> = []

    private var currentPage = 0

    func loadVideos() {
        isLoading = true
        Task {
            do {
                let fetched = try await APIClient.shared.fetchFeed(page: 0)
                videos = fetched
                currentPage = 0
            } catch {
                // Fallback to bundled seed videos when backend is unreachable
                print("[feed] API error, using bundled videos: \(error.localizedDescription)")
                videos = Video.mockFeed
            }
            isLoading = false
        }
    }

    func loadMore() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let nextPage = currentPage + 1
                let more = try await APIClient.shared.fetchFeed(page: nextPage)
                if !more.isEmpty {
                    videos.append(contentsOf: more)
                    currentPage = nextPage
                }
            } catch {
                print("[feed] Load more error: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    func trackView(videoId: String, loopCount: Int, watchDuration: TimeInterval) {
        // TODO: Send analytics to backend
        print("[analytics] video=\(videoId) loops=\(loopCount) duration=\(watchDuration)s")
    }

    func likeVideo(videoId: String) {
        let wasLiked = likedVideoIds.contains(videoId)

        // Optimistic toggle
        if wasLiked {
            likedVideoIds.remove(videoId)
        } else {
            likedVideoIds.insert(videoId)
        }

        // Optimistic count update
        if let index = videos.firstIndex(where: { $0.id == videoId }) {
            let v = videos[index]
            let newCount = wasLiked ? max(0, v.likeCount - 1) : v.likeCount + 1
            videos[index] = Video(
                id: v.id, username: v.username, caption: v.caption,
                videoURL: v.videoURL, thumbnailURL: v.thumbnailURL,
                likeCount: newCount, commentCount: v.commentCount,
                shareCount: v.shareCount, loopCount: v.loopCount,
                createdAt: v.createdAt
            )
        }

        // Sync with API
        guard let userId = AuthManager.shared.userId else { return }
        Task {
            do {
                let result = try await APIClient.shared.likeVideo(id: videoId, userId: userId)
                // Sync liked state with server
                if result.liked {
                    likedVideoIds.insert(videoId)
                } else {
                    likedVideoIds.remove(videoId)
                }
                // Update count from server
                if let index = videos.firstIndex(where: { $0.id == videoId }) {
                    let v = videos[index]
                    videos[index] = Video(
                        id: v.id, username: v.username, caption: v.caption,
                        videoURL: v.videoURL, thumbnailURL: v.thumbnailURL,
                        likeCount: result.likeCount, commentCount: v.commentCount,
                        shareCount: v.shareCount, loopCount: v.loopCount,
                        createdAt: v.createdAt
                    )
                }
            } catch {
                // Revert optimistic update on failure
                if wasLiked {
                    likedVideoIds.insert(videoId)
                } else {
                    likedVideoIds.remove(videoId)
                }
                print("[feed] Like API error: \(error.localizedDescription)")
            }
        }
    }

    func updateCommentCount(videoId: String, count: Int) {
        if let index = videos.firstIndex(where: { $0.id == videoId }) {
            let v = videos[index]
            videos[index] = Video(
                id: v.id, username: v.username, caption: v.caption,
                videoURL: v.videoURL, thumbnailURL: v.thumbnailURL,
                likeCount: v.likeCount, commentCount: count,
                shareCount: v.shareCount, loopCount: v.loopCount,
                createdAt: v.createdAt
            )
        }
    }
}
