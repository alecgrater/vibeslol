import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var currentIndex = 0

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
        // Optimistic update, then sync with API
        if let index = videos.firstIndex(where: { $0.id == videoId }) {
            let v = videos[index]
            videos[index] = Video(
                id: v.id, username: v.username, caption: v.caption,
                videoURL: v.videoURL, thumbnailURL: v.thumbnailURL,
                likeCount: v.likeCount + 1, commentCount: v.commentCount,
                shareCount: v.shareCount, loopCount: v.loopCount,
                createdAt: v.createdAt
            )
        }
        // TODO: Call APIClient.shared.likeVideo once user auth is wired up (Feature D)
    }
}
