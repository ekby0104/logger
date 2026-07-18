import AVFoundation
import CoreMedia
import UIKit

enum VideoComposerError: Error {
    case noSegments
    case trackCreationFailed
    case exportFailed
}

/// Merges recorded segments into a single clip and extracts thumbnails.
enum VideoComposer {
    static func merge(segmentURLs: [URL]) async throws -> URL {
        guard !segmentURLs.isEmpty else { throw VideoComposerError.noSegments }
        if segmentURLs.count == 1 { return segmentURLs[0] }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw VideoComposerError.trackCreationFailed }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var isFirst = true
        for url in segmentURLs {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let range = CMTimeRange(start: .zero, duration: duration)

            if let track = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(range, of: track, at: cursor)
                if isFirst {
                    videoTrack.preferredTransform = try await track.load(.preferredTransform)
                    isFirst = false
                }
            }
            if let track = try await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack?.insertTimeRange(range, of: track, at: cursor)
            }
            cursor = cursor + duration
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("moment-\(UUID().uuidString).mov")
        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else { throw VideoComposerError.exportFailed }
        export.outputURL = outputURL
        export.outputFileType = .mov
        await export.export()
        guard export.status == .completed else {
            throw export.error ?? VideoComposerError.exportFailed
        }
        return outputURL
    }

    static func thumbnail(for url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                continuation.resume(returning: cgImage.map { UIImage(cgImage: $0) })
            }
        }
    }
}
