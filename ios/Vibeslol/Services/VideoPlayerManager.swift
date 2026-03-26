import AVFoundation
import Combine
import SwiftUI

/// Manages a single AVPlayer that loops a 6-second video seamlessly.
final class VideoPlayerManager: ObservableObject {
    let player: AVQueuePlayer
    private var playerLooper: AVPlayerLooper?
    private var statusObserver: NSKeyValueObservation?
    private var timeObserver: Any?

    @Published var isPlaying = false
    @Published var isReady = false
    @Published var loopCount = 0

    private var currentLoopStart: CMTime = .zero

    init() {
        self.player = AVQueuePlayer()
        player.isMuted = false
        setupLoopTracking()
    }

    deinit {
        cleanup()
    }

    func loadVideo(url: URL) {
        cleanup()
        isReady = false
        loopCount = 0

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        playerLooper = AVPlayerLooper(player: player, templateItem: item)

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.isReady = item.status == .readyToPlay
            }
        }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func setupLoopTracking() {
        // Track loop completions via time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            // Detect loop restart: current time < previous observed time
            if time < self.currentLoopStart && self.currentLoopStart.seconds > 1 {
                self.loopCount += 1
            }
            self.currentLoopStart = time
        }
    }

    private func cleanup() {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        playerLooper?.disableLooping()
        playerLooper = nil
        player.removeAllItems()
        isPlaying = false
    }
}
