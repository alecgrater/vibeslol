import AVFoundation
import AVKit
import PhotosUI
import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.state {
            case .setup:
                ProgressView()
                    .tint(Color.vibePurple)
                    .onAppear { viewModel.setupCamera() }

            case .denied:
                permissionDeniedView

            case .ready:
                cameraLiveView

            case .countdown:
                cameraLiveView
                countdownOverlay

            case .recording:
                cameraLiveView
                recordingOverlay

            case .preview:
                if let url = viewModel.recordedVideoURL {
                    videoPreviewView(url: url)
                }

            case .trimming:
                if let url = viewModel.pickedVideoURL {
                    VideoTrimmerView(
                        url: url,
                        onComplete: { trimmedURL in
                            viewModel.handleTrimComplete(url: trimmedURL)
                        },
                        onCancel: {
                            viewModel.cancelTrim()
                        }
                    )
                }
            }
        }
        .onDisappear {
            viewModel.tearDown()
        }
        .statusBarHidden(true)
    }

    // MARK: - Camera Live Preview

    private var cameraLiveView: some View {
        ZStack {
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Top bar
            VStack {
                topControls
                Spacer()
                bottomControls
            }
            .padding(.bottom, 40)
        }
    }

    private var topControls: some View {
        HStack {
            // Close button
            Button {
                viewModel.tearDown()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
            }

            Spacer()

            // Flip camera
            Button {
                viewModel.flipCamera()
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // "6s" label
            Text("6s")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.vibePurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))

            HStack(spacing: 60) {
                // Upload from library
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .onChange(of: selectedItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let movie = try? await item.loadTransferable(type: MovieTransferable.self) {
                            viewModel.handlePickedVideo(url: movie.url)
                        }
                        selectedItem = nil
                    }
                }

                // Record button — tap for countdown, long press for immediate
                recordButton

                // Countdown timer toggle (tap to record with countdown)
                Button {
                    viewModel.startCountdown()
                } label: {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private var recordButton: some View {
        Button {
            viewModel.startRecordingImmediately()
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Inner filled circle
                Circle()
                    .fill(Color.vibePurple)
                    .frame(width: 66, height: 66)
                    .shadow(color: .vibePurple.opacity(0.5), radius: 10)
            }
        }
    }

    // MARK: - Countdown Overlay

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            Text("\(viewModel.countdownValue)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .vibePurple.opacity(0.6), radius: 20)
                .transition(.scale.combined(with: .opacity))
                .id(viewModel.countdownValue)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.countdownValue)

            // Cancel button
            VStack {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelCountdown()
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 80)
            }
        }
    }

    // MARK: - Recording Overlay

    private var recordingOverlay: some View {
        VStack {
            // Progress bar at top
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.vibePurple)
                        .frame(width: geo.size.width * viewModel.recordingProgress, height: 4)
                        .shadow(color: .vibePurple.opacity(0.6), radius: 4)
                        .animation(.linear(duration: 1.0 / 30.0), value: viewModel.recordingProgress)
                }
            }
            .frame(height: 4)
            .padding(.top, 8)

            Spacer()

            // Stop button
            Button {
                viewModel.stopRecording()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.6), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.bottom, 40)

            // Time remaining
            Text(String(format: "%.1fs", CameraViewModel.maxDuration * (1.0 - viewModel.recordingProgress)))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 20)
        }
    }

    // MARK: - Video Preview

    private func videoPreviewView(url: URL) -> some View {
        let player = AVPlayer(url: url)

        return ZStack {
            // Looping video preview
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear {
                    player.play()
                    // Loop playback
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: player.currentItem,
                        queue: .main
                    ) { _ in
                        player.seek(to: .zero)
                        player.play()
                    }
                }

            // Bottom controls
            VStack {
                Spacer()

                HStack(spacing: 40) {
                    // Retake
                    Button {
                        player.pause()
                        viewModel.retake()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                            Text("Retake")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }

                    // Use / Post (placeholder for future post flow)
                    Button {
                        player.pause()
                        HapticsService.shared.success()
                        // TODO: Navigate to post flow (add caption, upload)
                        // For now, save to the camera roll-ish location
                        if let videoURL = viewModel.useVideo() {
                            saveToDocuments(url: videoURL)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.vibePurple)
                                .shadow(color: .vibePurple.opacity(0.5), radius: 10)
                            Text("Use Video")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.vibePurple.opacity(0.6))

            Text("Camera Access Required")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Open Settings to allow Vibeslol\nto access your camera.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Open Settings")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.vibePurple))
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func saveToDocuments(url: URL) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dest = docs.appendingPathComponent("recorded_\(Int(Date().timeIntervalSince1970)).mov")
        try? FileManager.default.copyItem(at: url, to: dest)
        print("[camera] saved recording to \(dest.path)")
    }
}

#Preview {
    CameraView()
}
