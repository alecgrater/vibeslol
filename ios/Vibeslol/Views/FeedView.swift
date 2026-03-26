import SwiftUI
import AVFoundation

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var preloader = VideoPreloader()
    @ObservedObject private var auth = AuthManager.shared
    @State private var currentIndex: Int = 0
    @State private var navigationPath = NavigationPath()
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if viewModel.videos.isEmpty && !viewModel.isLoading {
                        emptyFollowingState
                    } else if viewModel.videos.isEmpty {
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
                                        viewModel: viewModel,
                                        navigationPath: $navigationPath
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

                    // Top nav bar
                    VStack {
                        topNavBar
                        Spacer()
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                viewModel.loadVideos()
                if !viewModel.videos.isEmpty {
                    preloader.updatePreload(videos: viewModel.videos, currentIndex: 0)
                    viewModel.onVideoAppear(videoId: viewModel.videos[0].id)
                }
            }
            .onDisappear {
                viewModel.onFeedDisappear()
            }
            .navigationDestination(for: String.self) { userId in
                UserProfileView(userId: userId)
                    .navigationBarBackButtonHidden()
            }
        }
    }

    // MARK: - Top Navigation Bar

    private var topNavBar: some View {
        HStack {
            // Left: profile avatar
            Button {
                selectedTab = .profile
                HapticsService.shared.lightTap()
            } label: {
                Circle()
                    .fill(Color.vibePurple.opacity(0.25))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(avatarInitial)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.vibePurple)
                    )
                    .shadow(color: .vibePurple.opacity(0.3), radius: 4)
            }

            Spacer()

            // Center: feed mode pill selector
            feedModePill

            Spacer()

            // Right: camera + notifications
            HStack(spacing: 16) {
                Button {
                    selectedTab = .record
                    HapticsService.shared.mediumTap()
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .vibePurple.opacity(0.3), radius: 4)
                }

                Button {
                    selectedTab = .notifications
                    HapticsService.shared.lightTap()
                } label: {
                    Image(systemName: "bell")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .vibePurple.opacity(0.3), radius: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
        .padding(.bottom, 8)
    }

    private var avatarInitial: String {
        if let user = auth.currentUser {
            return String(user.username.prefix(1)).uppercased()
        }
        return "?"
    }

    // MARK: - Feed Mode Pill

    private var feedModePill: some View {
        HStack(spacing: 0) {
            feedModeButton(title: "For You", mode: .forYou)
            feedModeButton(title: "Following", mode: .following)
        }
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    private func feedModeButton(title: String, mode: FeedMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.switchFeedMode(mode)
                currentIndex = 0
            }
        } label: {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(viewModel.feedMode == mode ? .white : .white.opacity(0.45))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    viewModel.feedMode == mode
                        ? Capsule().fill(Color.vibePurple.opacity(0.6))
                        : nil
                )
        }
    }

    private var emptyFollowingState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.2))
            Text("No videos from people you follow")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
            Button {
                viewModel.switchFeedMode(.forYou)
            } label: {
                Text("Browse For You")
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.vibePurple)
                    .cornerRadius(20)
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
    @Binding var navigationPath: NavigationPath

    @State private var showOverlay = true
    @State private var overlayTimer: Timer?
    @State private var showComments = false
    @State private var showShareSheet = false
    @State private var showReportSheet = false
    @State private var showDoubleTapHeart = false
    @State private var likeScale: CGFloat = 1.0

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

            // Tap to toggle play/overlay, double-tap to like
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    // Double-tap to like
                    if !isLiked {
                        viewModel.likeVideo(videoId: video.id)
                        HapticsService.shared.likeHaptic()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        showDoubleTapHeart = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showDoubleTapHeart = false
                        }
                    }
                }
                .onTapGesture {
                    playerManager.togglePlayback()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showOverlay.toggle()
                    }
                    resetOverlayTimer()
                }

            // Double-tap heart burst
            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .vibePurple.opacity(0.6), radius: 20)
                    .scaleEffect(showDoubleTapHeart ? 1.0 : 0.3)
                    .opacity(showDoubleTapHeart ? 1.0 : 0.0)
                    .transition(.scale.combined(with: .opacity))
            }

            // Pause icon flash
            if !playerManager.isPlaying && isActive {
                Image(systemName: "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.7))
                    .shadow(color: .vibePurple.opacity(0.3), radius: 10)
                    .transition(.opacity)
            }

            // Top gradient for caption readability (replaces bottom gradient)
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 250)
                Spacer()
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
                viewModel.onVideoAppear(videoId: video.id)
            } else {
                // Track watch analytics before pausing
                let loopCount = playerManager.loopCount
                viewModel.trackView(
                    videoId: video.id,
                    loopCount: loopCount,
                    watchDuration: Double(loopCount) * 6.0 + 3.0 // approximate
                )
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
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(videoId: video.id) {
                HapticsService.shared.success()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
    }

    private var overlayContent: some View {
        ZStack {
            // Top area: username + caption (below nav bar)
            VStack {
                VStack(alignment: .leading, spacing: 6) {
                    // Tappable username → navigate to profile
                    Button {
                        if let authorId = video.authorId {
                            navigationPath.append(authorId)
                        }
                    } label: {
                        Text("@\(video.username)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 3)
                    }
                    .disabled(video.authorId == nil)

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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.trailing, 80)
                .padding(.top, 110) // below the top nav bar

                Spacer()
            }

            // Bottom center: action pill
            VStack {
                Spacer()
                actionPill
                    .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Bottom Action Pill

    private var actionPill: some View {
        HStack(spacing: 28) {
            // Like
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.likeVideo(videoId: video.id)
                    HapticsService.shared.likeHaptic()
                    likeScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        likeScale = 1.0
                    }
                }
            } label: {
                pillAction(
                    icon: isLiked ? "heart.fill" : "heart",
                    count: video.likeCount,
                    color: isLiked ? .red : .white
                )
            }
            .scaleEffect(likeScale)

            // Comment
            Button {
                showComments = true
            } label: {
                pillAction(icon: "bubble.right", count: video.commentCount)
            }

            // Share
            Button {
                showShareSheet = true
            } label: {
                pillAction(icon: "arrowshape.turn.up.right", count: video.shareCount)
            }

            // Report
            Button {
                showReportSheet = true
            } label: {
                Image(systemName: "flag")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .shadow(color: .vibePurple.opacity(0.15), radius: 8)
    }

    private func pillAction(icon: String, count: Int, color: Color = .white) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .shadow(color: .vibePurple.opacity(0.3), radius: 4)
            Text(formatCount(count))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
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

    private func resetOverlayTimer() {
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showOverlay = false
            }
        }
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
    FeedView(selectedTab: .constant(.feed))
}
