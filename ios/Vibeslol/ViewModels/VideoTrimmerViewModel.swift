import AVFoundation
import SwiftUI

@MainActor
class VideoTrimmerViewModel: ObservableObject {
    // MARK: - Published State

    @Published var thumbnails: [UIImage] = []
    @Published var scrubPosition: Double = 0 // 0.0 → 1.0 normalized
    @Published var isExporting = false
    @Published var isLoading = true

    // MARK: - Video Data

    let videoURL: URL
    private let asset: AVAsset
    private(set) var duration: Double = 0

    static let clipDuration: Double = 6.0

    var startTime: Double {
        scrubPosition * max(0, duration - Self.clipDuration)
    }

    var endTime: Double {
        min(startTime + Self.clipDuration, duration)
    }

    // MARK: - Init

    init(url: URL) {
        self.videoURL = url
        self.asset = AVAsset(url: url)
    }

    // MARK: - Loading

    func load() async {
        do {
            let d = try await asset.load(.duration)
            duration = d.seconds
            isLoading = false
            await generateThumbnails()
        } catch {
            print("[trimmer] failed to load asset: \(error)")
        }
    }

    private func generateThumbnails() async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 80, height: 140)

        let count = 20
        var images: [UIImage] = []

        for i in 0..<count {
            let time = CMTime(
                seconds: duration * Double(i) / Double(count),
                preferredTimescale: 600
            )
            do {
                let (cgImage, _) = try await generator.image(at: time)
                images.append(UIImage(cgImage: cgImage))
            } catch {
                // Skip failed frames
            }
        }

        thumbnails = images
    }

    // MARK: - Export

    func exportTrimmedVideo() async -> URL? {
        isExporting = true
        defer { isExporting = false }

        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            return nil
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        } else {
            print("[trimmer] export failed: \(exportSession.error?.localizedDescription ?? "unknown")")
            return nil
        }
    }
}
