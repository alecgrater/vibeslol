import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class CameraViewModel: NSObject, ObservableObject {
    // MARK: - Published State

    enum CameraState {
        case setup       // Waiting for permission / initializing
        case ready       // Preview live, ready to record
        case countdown   // 3-2-1 countdown before recording
        case recording   // Actively recording
        case preview     // Showing recorded video for review
        case denied      // Camera permission denied
        case trimming    // Showing trim-to-6s scrubber for picked video
    }

    @Published var state: CameraState = .setup
    @Published var countdownValue: Int = 3
    @Published var recordingProgress: Double = 0  // 0.0 → 1.0 over 6 seconds
    @Published var recordedVideoURL: URL?
    @Published var isFlashOn = false
    @Published var isFrontCamera = true
    @Published var pickedVideoURL: URL?  // Video picked from library that needs trimming
    @Published var showPhotoPicker = false

    // MARK: - AVFoundation

    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let movieOutput = AVCaptureMovieFileOutput()

    // MARK: - Timers

    private var countdownTimer: Timer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    static let maxDuration: TimeInterval = 6.0

    // MARK: - Lifecycle

    func setupCamera() {
        Task {
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

            if cameraStatus == .notDetermined {
                await AVCaptureDevice.requestAccess(for: .video)
            }
            if micStatus == .notDetermined {
                await AVCaptureDevice.requestAccess(for: .audio)
            }

            let cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
            let micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

            guard cameraGranted else {
                state = .denied
                return
            }

            configureCaptureSession(withAudio: micGranted)
        }
    }

    private func configureCaptureSession(withAudio: Bool) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080

        // Video input
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: position
        ) else {
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoDeviceInput = input
            }
        } catch { return }

        // Audio input
        if withAudio, let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                    audioDeviceInput = audioInput
                }
            } catch {}
        }

        // Movie output — limit to 6 seconds
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: Self.maxDuration, preferredTimescale: 600)

            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = isFrontCamera
                }
            }
        }

        captureSession.commitConfiguration()

        // Start session on background queue
        Task.detached { [captureSession] in
            captureSession.startRunning()
        }

        state = .ready
    }

    // MARK: - Recording Controls

    func startCountdown() {
        guard state == .ready else { return }
        state = .countdown
        countdownValue = 3
        HapticsService.shared.lightTap()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.countdownValue -= 1
                HapticsService.shared.lightTap()
                if self.countdownValue <= 0 {
                    timer.invalidate()
                    self.countdownTimer = nil
                    self.beginRecording()
                }
            }
        }
    }

    func startRecordingImmediately() {
        guard state == .ready else { return }
        beginRecording()
    }

    private func beginRecording() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        state = .recording
        recordingProgress = 0
        recordingStartTime = Date()
        HapticsService.shared.mediumTap()

        // Progress timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else {
                    timer.invalidate()
                    return
                }
                let elapsed = Date().timeIntervalSince(start)
                self.recordingProgress = min(elapsed / Self.maxDuration, 1.0)

                if elapsed >= Self.maxDuration {
                    timer.invalidate()
                    self.recordingTimer = nil
                    // movieOutput will auto-stop at maxRecordedDuration
                }
            }
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        movieOutput.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        state = .ready
    }

    // MARK: - Preview Controls

    func retake() {
        // Clean up old recording
        if let url = recordedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedVideoURL = nil
        recordingProgress = 0
        state = .ready
    }

    func useVideo() -> URL? {
        // Return the URL for the caller to use (post flow, etc.)
        return recordedVideoURL
    }

    // MARK: - Camera Switching

    func flipCamera() {
        guard state == .ready else { return }
        isFrontCamera.toggle()
        HapticsService.shared.lightTap()

        captureSession.beginConfiguration()

        // Remove existing video input
        if let existing = videoDeviceInput {
            captureSession.removeInput(existing)
        }

        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: position
        ) else {
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoDeviceInput = input
            }
        } catch {}

        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCamera
            }
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Photo Library Pick

    func handlePickedVideo(url: URL) {
        Task {
            let asset = AVAsset(url: url)
            do {
                let duration = try await asset.load(.duration).seconds
                if duration <= CameraViewModel.maxDuration + 0.5 {
                    // Short enough — go straight to preview
                    recordedVideoURL = url
                    state = .preview
                    HapticsService.shared.success()
                } else {
                    // Needs trimming
                    pickedVideoURL = url
                    state = .trimming
                    HapticsService.shared.lightTap()
                }
            } catch {
                print("[camera] failed to load picked video duration: \(error)")
                state = .ready
            }
        }
    }

    func handleTrimComplete(url: URL) {
        recordedVideoURL = url
        pickedVideoURL = nil
        state = .preview
    }

    func cancelTrim() {
        if let url = pickedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        pickedVideoURL = nil
        state = .ready
    }

    // MARK: - Cleanup

    func tearDown() {
        countdownTimer?.invalidate()
        recordingTimer?.invalidate()
        Task.detached { [captureSession] in
            captureSession.stopRunning()
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordingProgress = 1.0

            if let error {
                // If it's just the max duration limit, that's fine
                let nsError = error as NSError
                if nsError.domain == AVFoundationErrorDomain &&
                    nsError.code == AVError.maximumDurationReached.rawValue {
                    recordedVideoURL = outputFileURL
                    state = .preview
                    HapticsService.shared.success()
                } else {
                    print("[camera] recording error: \(error.localizedDescription)")
                    state = .ready
                }
            } else {
                recordedVideoURL = outputFileURL
                state = .preview
                HapticsService.shared.success()
            }
        }
    }
}

// MARK: - MovieTransferable

struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
