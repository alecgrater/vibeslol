import Foundation

/// Preloads upcoming videos so the feed feels instant.
@MainActor
final class VideoPreloader: ObservableObject {
    private var managers: [String: VideoPlayerManager] = [:]
    private let preloadWindow = 2 // Preload N videos ahead

    func playerManager(for video: Video) -> VideoPlayerManager {
        if let existing = managers[video.id] {
            return existing
        }
        let manager = VideoPlayerManager()
        if let url = video.resolvedURL {
            manager.loadVideo(url: url)
        }
        managers[video.id] = manager
        return manager
    }

    func updatePreload(videos: [Video], currentIndex: Int) {
        let validRange = max(0, currentIndex - 1)...min(videos.count - 1, currentIndex + preloadWindow)
        let activeIDs = Set(videos[validRange].map(\.id))

        // Preload videos in range
        for i in validRange {
            let video = videos[i]
            let manager = playerManager(for: video)
            if i == currentIndex {
                manager.play()
            } else {
                manager.pause()
            }
        }

        // Evict videos outside range
        let evictIDs = Set(managers.keys).subtracting(activeIDs)
        for id in evictIDs {
            managers[id]?.pause()
            managers.removeValue(forKey: id)
        }
    }

    func pauseAll() {
        managers.values.forEach { $0.pause() }
    }
}
