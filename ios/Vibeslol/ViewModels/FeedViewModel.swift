import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var currentIndex = 0

    func loadVideos() {
        // TODO: Replace with API call
        isLoading = true
        videos = Video.mockFeed
        isLoading = false
    }

    func trackView(videoId: String, loopCount: Int, watchDuration: TimeInterval) {
        // TODO: Send analytics to backend
        print("[analytics] video=\(videoId) loops=\(loopCount) duration=\(watchDuration)s")
    }

    func likeVideo(videoId: String) {
        // TODO: API call
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
    }
}
