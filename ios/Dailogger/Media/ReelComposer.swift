import AVFoundation
import CoreMedia
import UIKit

/// Composes the day's clips into a single reel styled like the Timeline tab:
/// the video plays inside a white ink-bordered card with a hard shadow on a
/// paper background, next to a dashed timeline rail with a purple dot.
/// Each moment's segment shows its time label and caption; the blog text
/// floats over the media on a translucent ink panel.
enum ReelComposer {
    private static let ink = UIColor(red: 0x13 / 255, green: 0x18 / 255, blue: 0x26 / 255, alpha: 1)
    private static let paper = UIColor(red: 0xF4 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)
    private static let gray = UIColor(red: 0x4F / 255, green: 0x56 / 255, blue: 0x63 / 255, alpha: 1)
    private static let purple = UIColor(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255, alpha: 1)

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

        // ----- Timeline-card layout (computed top-down, converted to CA's
        // bottom-left origin via flipY) -----
        let W = renderSize.width
        let H = renderSize.height
        let scale = W / 390
        func flipY(_ topY: CGFloat, _ height: CGFloat) -> CGFloat { H - topY - height }

        let border = 2 * scale
        let cardRadius = 16 * scale
        let shadowOffset = 6 * scale
        let lineX = 47 * scale
        let cardMinX = 56 * scale
        let rightMargin = 14 * scale
        let captionStripH = 64 * scale
        let topMargin = H * 0.08
        let bottomMargin = H * 0.09

        // Media area keeps the source aspect so the video isn't distorted.
        let aspect = W / H
        let availH = H - topMargin - bottomMargin - captionStripH - border * 2
        let availW = W - cardMinX - rightMargin - border * 2
        var mediaH = availH
        var mediaW = availH * aspect
        if mediaW > availW {
            mediaW = availW
            mediaH = availW / aspect
        }

        let cardW = mediaW + border * 2
        let cardH = border + mediaH + captionStripH + border
        let cardTop = topMargin
        // Center the card in the space right of the rail so leftover width
        // splits evenly instead of piling up on the right edge.
        let cardX = cardMinX + max(availW + border * 2 - cardW, 0) / 2
        let mediaX = cardX + border
        let mediaTop = cardTop + border

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.backgroundColor = paper.cgColor

        // Dashed rail + purple dot
        let railHeight = cardH + 32 * scale
        let railImage = ReelOverlayRenderer.dashedLine(height: railHeight, width: 2 * scale, ink: ink)
        parentLayer.addSublayer(imageLayer(
            railImage,
            origin: CGPoint(x: lineX - scale, y: flipY(cardTop - 16 * scale, railHeight))
        ))

        let dotDiameter = 14 * scale
        let dotImage = ReelOverlayRenderer.dot(diameter: dotDiameter, fill: purple, ink: ink, border: border)
        parentLayer.addSublayer(imageLayer(
            dotImage,
            origin: CGPoint(x: lineX - dotDiameter / 2, y: flipY(cardTop + 3 * scale, dotDiameter))
        ))

        // Card (white, ink border, hard shadow)
        let cardImage = ReelOverlayRenderer.cardWithShadow(
            size: CGSize(width: cardW, height: cardH),
            radius: cardRadius,
            border: border,
            shadowOffset: shadowOffset,
            ink: ink
        )
        parentLayer.addSublayer(imageLayer(
            cardImage,
            origin: CGPoint(x: cardX, y: flipY(cardTop, cardH + shadowOffset))
        ))

        // Video plays inside the card's media area.
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(
            x: mediaX,
            y: flipY(mediaTop, mediaH),
            width: mediaW,
            height: mediaH
        )
        videoLayer.cornerRadius = max(cardRadius - border, 0)
        videoLayer.masksToBounds = true
        parentLayer.addSublayer(videoLayer)

        // Per-segment time label (left of the dot) and caption (card footer)
        for segment in segments {
            let timeImage = ReelOverlayRenderer.plainText(
                segment.moment.timeLabel,
                fontSize: 12 * scale,
                color: gray,
                maxWidth: cardX
            )
            let timeLayer = imageLayer(
                timeImage,
                origin: CGPoint(
                    x: lineX - 10 * scale - timeImage.size.width,
                    y: flipY(cardTop + 10 * scale - timeImage.size.height / 2, timeImage.size.height)
                )
            )
            setVisibility(timeLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
            parentLayer.addSublayer(timeLayer)

            let caption = truncated(segment.moment.caption, limit: 110)
            if !caption.isEmpty {
                let captionImage = ReelOverlayRenderer.plainText(
                    caption,
                    fontSize: 13 * scale,
                    color: ink,
                    maxWidth: mediaW - 24 * scale,
                    maxHeight: captionStripH - 16 * scale
                )
                let captionLayer = imageLayer(
                    captionImage,
                    origin: CGPoint(
                        x: mediaX + 12 * scale,
                        y: flipY(mediaTop + mediaH + 8 * scale, captionImage.size.height)
                    )
                )
                setVisibility(captionLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
                parentLayer.addSublayer(captionLayer)
            }
        }

        // Blog text floats over the media on a translucent ink panel.
        let trimmedBlog = blogText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBlog.isEmpty {
            let display = truncated(trimmedBlog, limit: 220)
            let blogImage = ReelOverlayRenderer.blogPanel(
                display,
                fontSize: 13 * scale,
                maxWidth: mediaW * 0.85,
                ink: ink
            )
            parentLayer.addSublayer(imageLayer(
                blogImage,
                origin: CGPoint(
                    x: mediaX + (mediaW - blogImage.size.width) / 2,
                    y: flipY(mediaTop + (mediaH - blogImage.size.height) / 2, blogImage.size.height)
                )
            ))
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

    // MARK: - Helpers

    private static func truncated(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }

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

/// Draws the timeline-styled overlay images: paper-and-ink cards, dashed
/// rail, purple dot, plain Chalkboard text, and the translucent blog panel.
enum ReelOverlayRenderer {
    private static func font(_ size: CGFloat) -> UIFont {
        UIFont(name: "ChalkboardSE-Bold", size: size)
            ?? UIFont.boldSystemFont(ofSize: size)
    }

    /// White rounded card with ink border and hard offset shadow.
    /// The image is (size + shadowOffset) large; the card sits at origin.
    static func cardWithShadow(
        size: CGSize,
        radius: CGFloat,
        border: CGFloat,
        shadowOffset: CGFloat,
        ink: UIColor
    ) -> UIImage {
        let imageSize = CGSize(width: size.width + shadowOffset, height: size.height + shadowOffset)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { _ in
            let shadowRect = CGRect(
                x: shadowOffset, y: shadowOffset,
                width: size.width, height: size.height
            )
            ink.setFill()
            UIBezierPath(roundedRect: shadowRect, cornerRadius: radius).fill()

            let cardRect = CGRect(origin: .zero, size: size)
                .insetBy(dx: border / 2, dy: border / 2)
            let card = UIBezierPath(roundedRect: cardRect, cornerRadius: radius)
            UIColor.white.setFill()
            card.fill()
            ink.setStroke()
            card.lineWidth = border
            card.stroke()
        }
    }

    static func dashedLine(height: CGFloat, width: CGFloat, ink: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: width / 2, y: 0))
            path.addLine(to: CGPoint(x: width / 2, y: height))
            path.lineWidth = width
            path.setLineDash([width * 2.5, width * 2.5], count: 2, phase: 0)
            ink.setStroke()
            path.stroke()
        }
    }

    static func dot(diameter: CGFloat, fill: UIColor, ink: UIColor, border: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { _ in
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
                .insetBy(dx: border / 2, dy: border / 2)
            let path = UIBezierPath(ovalIn: rect)
            fill.setFill()
            path.fill()
            ink.setStroke()
            path.lineWidth = border
            path.stroke()
        }
    }

    /// Plain wrapped text; height optionally capped (pre-truncate the string
    /// so the cap doesn't cut mid-line in normal cases).
    static func plainText(
        _ text: String,
        fontSize: CGFloat,
        color: UIColor,
        maxWidth: CGFloat,
        maxHeight: CGFloat? = nil
    ) -> UIImage {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineSpacing = fontSize * 0.2

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(fontSize),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )
        var size = CGSize(width: ceil(bounding.width), height: ceil(bounding.height))
        if let maxHeight {
            size.height = min(size.height, maxHeight)
        }

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

    /// Centered blog text on a translucent ink panel with a white border —
    /// readable over the footage without fully hiding it.
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
        let border = max(fontSize * 0.14, 2)
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
