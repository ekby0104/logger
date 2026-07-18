import AVFoundation
import CoreMedia
import UIKit

/// Composes the day's clips into a single reel with app-styled text overlays:
/// a time·place pill and the caption shown during each moment's segment,
/// plus the blog text centered across the whole video.
enum ReelComposer {
    private static let ink = UIColor(red: 0x13 / 255, green: 0x18 / 255, blue: 0x26 / 255, alpha: 1)

    static func makeReel(moments: [Moment], blogText: String) async throws -> URL {
        let clips: [(moment: Moment, url: URL)] = moments.compactMap { moment in
            guard let url = moment.videoURL else { return nil }
            return (moment, url)
        }
        guard !clips.isEmpty else { throw VideoComposerError.noSegments }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw VideoComposerError.trackCreationFailed }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var segments: [(moment: Moment, start: CMTime, duration: CMTime)] = []
        var sourceTransform = CGAffineTransform.identity
        var sourceSize = CGSize(width: 1080, height: 1920)
        var isFirst = true

        for clip in clips {
            let asset = AVURLAsset(url: clip.url)
            let duration = try await asset.load(.duration)
            let range = CMTimeRange(start: .zero, duration: duration)
            if let track = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(range, of: track, at: cursor)
                if isFirst {
                    sourceTransform = try await track.load(.preferredTransform)
                    sourceSize = try await track.load(.naturalSize)
                    isFirst = false
                }
            }
            if let track = try await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack?.insertTimeRange(range, of: track, at: cursor)
            }
            segments.append((clip.moment, cursor, duration))
            cursor = cursor + duration
        }

        let transformed = CGRect(origin: .zero, size: sourceSize).applying(sourceTransform)
        let renderSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        let total = cursor
        let totalSeconds = CMTimeGetSeconds(total)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: total)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let originFix = CGAffineTransform(
            translationX: transformed.minX < 0 ? -transformed.minX : 0,
            y: transformed.minY < 0 ? -transformed.minY : 0
        )
        layerInstruction.setTransform(sourceTransform.concatenating(originFix), at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Overlay layer tree. Core Animation origin is bottom-left,
        // so y positions are measured from the bottom of the frame.
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        let scale = renderSize.width / 390
        let margin = 20 * scale

        for segment in segments {
            let pillImage = ReelOverlayRenderer.pill(
                "\(segment.moment.timeLabel) · \(segment.moment.placeName)",
                fontSize: 13 * scale,
                ink: ink
            )
            let pillLayer = imageLayer(pillImage, origin: CGPoint(x: margin, y: margin))
            setVisibility(pillLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
            parentLayer.addSublayer(pillLayer)

            let caption = segment.moment.caption
            if !caption.isEmpty {
                let captionImage = ReelOverlayRenderer.outlinedText(
                    caption,
                    fontSize: 16 * scale,
                    maxWidth: renderSize.width - margin * 2,
                    alignment: .left,
                    ink: ink
                )
                let captionLayer = imageLayer(
                    captionImage,
                    origin: CGPoint(x: margin, y: margin + pillImage.size.height + 10 * scale)
                )
                setVisibility(captionLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
                parentLayer.addSublayer(captionLayer)
            }
        }

        let trimmedBlog = blogText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBlog.isEmpty {
            let display = trimmedBlog.count > 220
                ? String(trimmedBlog.prefix(220)) + "…"
                : trimmedBlog
            let blogImage = ReelOverlayRenderer.outlinedText(
                display,
                fontSize: 17 * scale,
                maxWidth: renderSize.width * 0.8,
                alignment: .center,
                ink: ink
            )
            let blogLayer = imageLayer(
                blogImage,
                origin: CGPoint(
                    x: (renderSize.width - blogImage.size.width) / 2,
                    y: (renderSize.height - blogImage.size.height) / 2
                )
            )
            parentLayer.addSublayer(blogLayer)
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parentLayer
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reel-\(UUID().uuidString).mov")
        guard let export = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality
        ) else { throw VideoComposerError.exportFailed }
        export.outputURL = outputURL
        export.outputFileType = .mov
        export.videoComposition = videoComposition
        await export.export()
        guard export.status == .completed else {
            throw export.error ?? VideoComposerError.exportFailed
        }
        return outputURL
    }

    // MARK: - Layer helpers

    private static func imageLayer(_ image: UIImage, origin: CGPoint) -> CALayer {
        let layer = CALayer()
        layer.contents = image.cgImage
        layer.frame = CGRect(origin: origin, size: image.size)
        return layer
    }

    /// Shows the layer only during [start, start+duration] using a keyframe
    /// opacity animation spanning the whole timeline.
    private static func setVisibility(
        _ layer: CALayer,
        start: CMTime,
        duration: CMTime,
        totalSeconds: Double
    ) {
        guard totalSeconds > 0 else { return }
        let startFraction = CMTimeGetSeconds(start) / totalSeconds
        let endFraction = min(
            (CMTimeGetSeconds(start) + CMTimeGetSeconds(duration)) / totalSeconds, 1
        )

        layer.opacity = 0
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.duration = totalSeconds
        animation.keyTimes = [
            0,
            NSNumber(value: startFraction),
            NSNumber(value: startFraction),
            NSNumber(value: endFraction),
            NSNumber(value: endFraction),
            1
        ]
        animation.values = [0, 0, 1, 1, 0, 0]
        animation.isRemovedOnCompletion = false
        animation.fillMode = .both
        layer.add(animation, forKey: "reelVisibility")
    }
}

// MARK: - App-styled overlay rendering

/// Draws overlay images in the app's neo-brutal style:
/// white pills with ink borders, and white Chalkboard text with an ink outline.
enum ReelOverlayRenderer {
    static func pill(_ text: String, fontSize: CGFloat, ink: UIColor) -> UIImage {
        let font = UIFont(name: "ChalkboardSE-Bold", size: fontSize)
            ?? UIFont.boldSystemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ink
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padH = fontSize * 0.9
        let padV = fontSize * 0.45
        let borderWidth = max(fontSize * 0.14, 2)
        let size = CGSize(
            width: ceil(textSize.width) + padH * 2,
            height: ceil(textSize.height) + padV * 2
        )

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
                .insetBy(dx: borderWidth / 2 + 1, dy: borderWidth / 2 + 1)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
            UIColor.white.setFill()
            path.fill()
            ink.setStroke()
            path.lineWidth = borderWidth
            path.stroke()
            (text as NSString).draw(
                at: CGPoint(x: padH, y: padV),
                withAttributes: attributes
            )
        }
    }

    static func outlinedText(
        _ text: String,
        fontSize: CGFloat,
        maxWidth: CGFloat,
        alignment: NSTextAlignment,
        ink: UIColor
    ) -> UIImage {
        let font = UIFont(name: "ChalkboardSE-Bold", size: fontSize)
            ?? UIFont.boldSystemFont(ofSize: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = fontSize * 0.3

        let shadow = NSShadow()
        shadow.shadowColor = ink
        shadow.shadowOffset = CGSize(width: fontSize * 0.12, height: fontSize * 0.12)
        shadow.shadowBlurRadius = 0

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .strokeColor: ink,
            .strokeWidth: -3.5,
            .paragraphStyle: paragraph,
            .shadow: shadow
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )
        let size = CGSize(
            width: ceil(bounding.width) + fontSize * 0.3,
            height: ceil(bounding.height) + fontSize * 0.3
        )

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            (text as NSString).draw(
                with: CGRect(origin: .zero, size: size),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            )
        }
    }
}
