import SwiftUI
import AVFoundation

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var preloader = VideoPreloader()
    @State private var currentIndex: Int = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.videos.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color.vibePurple)
                        Text("loading vibes...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                VideoCell(
                                    video: video,
                                    playerManager: preloader.playerManager(for: video),
                                    isActive: index == currentIndex,
                                    screenSize: geometry.size,
                                    viewModel: viewModel
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: Binding(
                        get: { currentIndex },
                        set: { newValue in
                            if let newValue {
                                let oldIndex = currentIndex
                                currentIndex = newValue
                                if oldIndex != newValue {
                                    HapticsService.shared.scrollSnap()
                                    preloader.updatePreload(
                                        videos: viewModel.videos,
                                        currentIndex: newValue
                                    )
                                }
                            }
                        }
                    ))
                    .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.loadVideos()
            if !viewModel.videos.isEmpty {
                preloader.updatePreload(videos: viewModel.videos, currentIndex: 0)
            }
        }
    }
}

// MARK: - Video Cell

struct VideoCell: View {
    let video: Video
    @ObservedObject var playerManager: VideoPlayerManager
    let isActive: Bool
    let screenSize: CGSize
    @ObservedObject var viewModel: FeedViewModel

    @State private var showOverlay = true
    @State private var overlayTimer: Timer?
    @State private var showComments = false
    @State private var showShareSheet = false

    private var isLiked: Bool {
        viewModel.likedVideoIds.contains(video.id)
    }

    var body: some View {
        ZStack {
            // Video player
            if !video.videoURL.isEmpty {
                VideoPlayerView(player: playerManager.player)
                    .ignoresSafeArea()
            } else {
                Color.black
            }

            // Tap to toggle play/overlay
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    playerManager.togglePlayback()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showOverlay.toggle()
                    }
                    resetOverlayTimer()
                }

            // Pause icon flash
            if !playerManager.isPlaying && isActive {
                Image(systemName: "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.7))
                    .shadow(color: .vibePurple.opacity(0.3), radius: 10)
                    .transition(.opacity)
            }

            // Bottom gradient for readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 250)
            }
            .ignoresSafeArea()

            // UI overlay
            if showOverlay {
                overlayContent
                    .transition(.opacity)
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                playerManager.play()
                resetOverlayTimer()
            } else {
                playerManager.pause()
            }
        }
        .sheet(isPresented: $showComments) {
            CommentSheetView(videoId: video.id) { newCount in
                viewModel.updateCommentCount(videoId: video.id, count: newCount)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(video: video)
                .presentationDetents([.medium])
        }
    }

    private var overlayContent: some View {
        HStack(alignment: .bottom) {
            // Left: creator info
            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                Text("@\(video.username)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3)

                if let caption = video.caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.6), radius: 3)
                }

                // Loop counter
                HStack(spacing: 4) {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.caption2)
                    Text("\(playerManager.loopCount)")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.4))
            }
            .padding(.leading, 16)
            .padding(.bottom, 100)

            Spacer()

            // Right: action buttons
            VStack(spacing: 24) {
                Spacer()

                ActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    count: video.likeCount,
                    color: isLiked ? .red : .white
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        viewModel.likeVideo(videoId: video.id)
                        HapticsService.shared.likeHaptic()
                    }
                }

                ActionButton(icon: "bubble.right", count: video.commentCount) {
                    showComments = true
                }

                ActionButton(icon: "arrowshape.turn.up.right", count: video.shareCount) {
                    showShareSheet = true
                }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 100)
        }
    }

    private func resetOverlayTimer() {
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showOverlay = false
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let count: Int
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .shadow(color: .vibePurple.opacity(0.3), radius: 4)

                Text(formatCount(count))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let video: Video

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = []

        // Share the video caption or a default text
        let shareText = "Check out this vibe on Vibeslol! \(video.caption ?? "")"
        items.append(shareText)

        // If we have a URL, share it
        if let url = video.resolvedURL {
            items.append(url)
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    FeedView()
}
