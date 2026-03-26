import AVFoundation
import AVKit
import SwiftUI

struct VideoTrimmerView: View {
    @StateObject private var viewModel: VideoTrimmerViewModel
    let onComplete: (URL) -> Void
    let onCancel: () -> Void

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var dragStartScrub: Double = 0

    init(url: URL, onComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: VideoTrimmerViewModel(url: url))
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(Color.vibePurple)
            } else {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Video preview
                    videoPreview
                        .frame(maxWidth: .infinity)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)

                    Spacer().frame(height: 24)

                    // Time indicator
                    HStack {
                        Text(formatTime(viewModel.startTime))
                        Spacer()
                        Text("6.0s")
                            .foregroundColor(.vibePurple)
                        Spacer()
                        Text(formatTime(viewModel.endTime))
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 12)

                    // Thumbnail scrubber
                    thumbnailScrubber
                        .padding(.horizontal, 16)

                    Spacer()

                    // Buttons
                    bottomButtons
                        .padding(.bottom, 50)
                }
            }
        }
        .task {
            await viewModel.load()
            setupPlayer()
        }
        .onDisappear {
            tearDownPlayer()
        }
        .statusBarHidden(true)
    }

    // MARK: - Video Preview

    private var videoPreview: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                Color.black
            }
        }
    }

    // MARK: - Thumbnail Scrubber

    private var thumbnailScrubber: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let thumbHeight: CGFloat = 56
            let clipFraction = min(
                1.0,
                VideoTrimmerViewModel.clipDuration / max(0.01, viewModel.duration)
            )
            let selectionWidth = totalWidth * CGFloat(clipFraction)
            let maxOffset = totalWidth - selectionWidth
            let currentOffset = CGFloat(viewModel.scrubPosition) * maxOffset

            ZStack(alignment: .leading) {
                // Full thumbnail strip (dimmed)
                thumbnailStrip(totalWidth: totalWidth, height: thumbHeight)
                    .overlay(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Selection window — bright thumbnails show through
                thumbnailStrip(totalWidth: totalWidth, height: thumbHeight)
                    .offset(x: -currentOffset)
                    .frame(width: selectionWidth, height: thumbHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.vibePurple, lineWidth: 3)
                    )
                    .overlay(
                        HStack {
                            grabHandle
                            Spacer()
                            grabHandle
                        }
                    )
                    .shadow(color: .vibePurple.opacity(0.4), radius: 6)
                    .offset(x: currentOffset)
            }
            .frame(height: thumbHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation.width == 0 && value.translation.height == 0 {
                            dragStartScrub = viewModel.scrubPosition
                        }
                        let delta = value.translation.width
                        let normalizedDelta = maxOffset > 0 ? Double(delta / maxOffset) : 0
                        let newPosition = dragStartScrub + normalizedDelta
                        viewModel.scrubPosition = max(0, min(1, newPosition))
                        seekPlayer()
                    }
            )
        }
        .frame(height: 56)
    }

    private func thumbnailStrip(totalWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(
                Array(viewModel.thumbnails.enumerated()), id: \.offset
            ) { _, image in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: totalWidth / CGFloat(max(1, viewModel.thumbnails.count)),
                        height: height
                    )
                    .clipped()
            }
        }
        .frame(height: height)
    }

    private var grabHandle: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 3, height: 20)
            .padding(.horizontal, 4)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 40) {
            Button {
                onCancel()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.title2)
                    Text("Cancel")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.8))
            }

            Button {
                Task {
                    if let url = await viewModel.exportTrimmedVideo() {
                        HapticsService.shared.success()
                        onComplete(url)
                    }
                }
            } label: {
                VStack(spacing: 6) {
                    if viewModel.isExporting {
                        ProgressView()
                            .tint(.vibePurple)
                            .frame(width: 56, height: 56)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.vibePurple)
                            .shadow(color: .vibePurple.opacity(0.5), radius: 10)
                    }
                    Text("Use Clip")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .disabled(viewModel.isExporting)
        }
    }

    // MARK: - Player Management

    private func setupPlayer() {
        let p = AVPlayer(url: viewModel.videoURL)
        p.seek(
            to: CMTime(seconds: viewModel.startTime, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        p.play()

        // Periodic observer to loop within the 6s window
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let observer = p.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak p] time in
            guard let p else { return }
            let current = time.seconds
            let end = viewModel.endTime
            if current >= end - 0.05 {
                p.seek(
                    to: CMTime(seconds: viewModel.startTime, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                )
            }
        }

        self.player = p
        self.timeObserver = observer
    }

    private func seekPlayer() {
        player?.seek(
            to: CMTime(seconds: viewModel.startTime, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        player?.play()
    }

    private func tearDownPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
        timeObserver = nil
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let frac = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        let mins = s / 60
        let secs = s % 60
        if mins > 0 {
            return String(format: "%d:%02d.%d", mins, secs, frac)
        }
        return String(format: "%d.%ds", secs, frac)
    }
}
