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

        let contentWidth = renderSize.width - margin * 2

        for segment in segments {
            let pillImage = ReelOverlayRenderer.pill(
                "\(segment.moment.timeLabel) · \(segment.moment.placeName)",
                fontSize: 13 * scale,
                maxWidth: contentWidth,
                ink: ink
            )
            let pillLayer = imageLayer(pillImage, origin: CGPoint(x: margin, y: margin))
            setVisibility(pillLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
            parentLayer.addSublayer(pillLayer)

            let caption = segment.moment.caption
            if !caption.isEmpty {
                let captionImage = ReelOverlayRenderer.captionBox(
                    caption,
                    fontSize: 14 * scale,
                    maxWidth: contentWidth,
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
            let blogImage = ReelOverlayRenderer.blogPanel(
                display,
                fontSize: 15 * scale,
                maxWidth: renderSize.width * 0.84,
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
/// white boxes with ink borders and ink text, plus a translucent ink
/// panel with white text for the blog content.
enum ReelOverlayRenderer {
    private static func font(_ size: CGFloat) -> UIFont {
        UIFont(name: "ChalkboardSE-Bold", size: size)
            ?? UIFont.boldSystemFont(ofSize: size)
    }

    private static func lineWidth(_ fontSize: CGFloat) -> CGFloat {
        max(fontSize * 0.14, 2)
    }

    /// Single-line white pill (ink border, ink text). Shrinks the font and
    /// finally truncates so it always fits within maxWidth.
    static func pill(_ text: String, fontSize: CGFloat, maxWidth: CGFloat, ink: UIColor) -> UIImage {
        func textWidth(_ string: String, _ size: CGFloat) -> CGFloat {
            (string as NSString).size(withAttributes: [.font: font(size)]).width
        }

        var size = fontSize
        var display = text
        let padH = fontSize * 0.9
        let minSize = fontSize * 0.6

        while textWidth(display, size) + padH * 2 > maxWidth && size > minSize {
            size *= 0.93
        }
        if textWidth(display, size) + padH * 2 > maxWidth {
            while display.count > 4,
                  textWidth(display + "…", size) + padH * 2 > maxWidth {
                display = String(display.dropLast())
            }
            display += "…"
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(size),
            .foregroundColor: ink
        ]
        let textSize = (display as NSString).size(withAttributes: attributes)
        let padV = size * 0.5
        let border = lineWidth(fontSize)
        let imageSize = CGSize(
            width: ceil(textSize.width) + padH * 2,
            height: ceil(textSize.height) + padV * 2
        )

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: imageSize)
                .insetBy(dx: border / 2 + 1, dy: border / 2 + 1)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
            UIColor.white.setFill()
            path.fill()
            ink.setStroke()
            path.lineWidth = border
            path.stroke()
            (display as NSString).draw(
                at: CGPoint(x: padH, y: padV),
                withAttributes: attributes
            )
        }
    }

    /// Multiline white rounded box (ink border, ink text) — same look as the
    /// info rows in the Edit screen. Text wraps within maxWidth.
    static func captionBox(_ text: String, fontSize: CGFloat, maxWidth: CGFloat, ink: UIColor) -> UIImage {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineSpacing = fontSize * 0.2

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(fontSize),
            .foregroundColor: ink,
            .paragraphStyle: paragraph
        ]
        let padding = fontSize * 0.7
        let border = lineWidth(fontSize)
        let textMaxWidth = maxWidth - padding * 2
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )
        let textSize = CGSize(width: ceil(bounding.width), height: ceil(bounding.height))
        let imageSize = CGSize(
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: imageSize)
                .insetBy(dx: border / 2 + 1, dy: border / 2 + 1)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: fontSize * 0.8)
            UIColor.white.setFill()
            path.fill()
            ink.setStroke()
            path.lineWidth = border
            path.stroke()
            (text as NSString).draw(
                with: CGRect(origin: CGPoint(x: padding, y: padding), size: textSize),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            )
        }
    }

    /// Centered blog text on a translucent ink panel with a white border —
    /// readable over any footage without fully hiding it (same style as the
    /// camera screen's timer pill).
    static func blogPanel(_ text: String, fontSize: CGFloat, maxWidth: CGFloat, ink: UIColor) -> UIImage {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = fontSize * 0.3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(fontSize),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        let padding = fontSize * 0.9
        let border = lineWidth(fontSize)
        let textMaxWidth = maxWidth - padding * 2
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )
        let textSize = CGSize(width: ceil(bounding.width), height: ceil(bounding.height))
        let imageSize = CGSize(
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: imageSize)
                .insetBy(dx: border / 2 + 1, dy: border / 2 + 1)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: fontSize)
            ink.withAlphaComponent(0.55).setFill()
            path.fill()
            UIColor.white.setStroke()
            path.lineWidth = border
            path.stroke()
            (text as NSString).draw(
                with: CGRect(origin: CGPoint(x: padding, y: padding), size: textSize),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            )
        }
    }
}
