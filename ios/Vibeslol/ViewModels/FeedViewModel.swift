import Foundation
import Combine

enum FeedMode {
    case forYou
    case following
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var currentIndex = 0
    @Published var likedVideoIds: Set<String> = []
    @Published var feedMode: FeedMode = .forYou

    private var currentPage = 0

    // Analytics tracking state
    private var videoStartTime: Date?
    private var currentVideoId: String?

    func loadVideos() {
        isLoading = true
        currentPage = 0
        Task {
            do {
                let fetched: [Video]
                let userId = AuthManager.shared.userId
                switch feedMode {
                case .forYou:
                    fetched = try await APIClient.shared.fetchFeed(page: 0, userId: userId)
                case .following:
                    guard let userId = userId else {
                        videos = []
                        isLoading = false
                        return
                    }
                    fetched = try await APIClient.shared.fetchFollowingFeed(userId: userId, page: 0)
                }
                videos = fetched
            } catch {
                print("[feed] API error, using bundled videos: \(error.localizedDescription)")
                videos = feedMode == .forYou ? Video.mockFeed : []
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
                let more: [Video]
                let userId = AuthManager.shared.userId
                switch feedMode {
                case .forYou:
                    more = try await APIClient.shared.fetchFeed(page: nextPage, userId: userId)
                case .following:
                    guard let userId = userId else {
                        isLoading = false
                        return
                    }
                    more = try await APIClient.shared.fetchFollowingFeed(userId: userId, page: nextPage)
                }
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

    func switchFeedMode(_ mode: FeedMode) {
        guard mode != feedMode else { return }
        feedMode = mode
        videos = []
        currentIndex = 0
        loadVideos()
    }

    // MARK: - Analytics Tracking

    /// Call when a video becomes the active (visible) video in the feed.
    func onVideoAppear(videoId: String) {
        // Send analytics for the previous video before switching
        flushCurrentWatch()

        currentVideoId = videoId
        videoStartTime = Date()
    }

    /// Call when leaving the feed entirely.
    func onFeedDisappear() {
        flushCurrentWatch()
    }

    /// Send the watch event for the current video to the backend.
    func trackView(videoId: String, loopCount: Int, watchDuration: TimeInterval) {
        guard let userId = AuthManager.shared.userId else { return }

        let watchMs = Int(watchDuration * 1000)
        let skipped = watchDuration < 3.0  // watched less than half of 6s = skip
        let watchPct = min(watchDuration / 6.0, Double(max(loopCount, 1)))

        Task {
            do {
                try await APIClient.shared.trackWatchEvent(
                    userId: userId,
                    videoId: videoId,
                    watchDurationMs: watchMs,
                    loopCount: loopCount,
                    skipped: skipped,
                    watchPercentage: watchPct
                )
            } catch {
                print("[analytics] Failed to track watch: \(error.localizedDescription)")
            }
        }
    }

    /// Flush the current video watch session (called on video change or feed disappear).
    private func flushCurrentWatch() {
        guard let videoId = currentVideoId, let startTime = videoStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)

        // We'll send the loop count as 0 here — the actual loop count will come
        // from the VideoCell which has access to playerManager.loopCount
        // This is a fallback; the primary trackView call happens from FeedView
        currentVideoId = nil
        videoStartTime = nil

        // Only track if they watched at least 0.5s (filter out scroll-throughs)
        guard duration >= 0.5 else { return }
        trackView(videoId: videoId, loopCount: 0, watchDuration: duration)
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
                id: v.id, authorId: v.authorId, username: v.username, caption: v.caption,
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
                        id: v.id, authorId: v.authorId, username: v.username, caption: v.caption,
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
                id: v.id, authorId: v.authorId, username: v.username, caption: v.caption,
                videoURL: v.videoURL, thumbnailURL: v.thumbnailURL,
                likeCount: v.likeCount, commentCount: count,
                shareCount: v.shareCount, loopCount: v.loopCount,
                createdAt: v.createdAt
            )
        }
    }
}
