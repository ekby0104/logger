import AVFoundation
import CoreMedia
import UIKit

/// Reel visual style.
enum ReelStyle {
    /// Video inside a white ink-bordered card on paper, with the dashed
    /// timeline rail, purple dot, time label, and card-footer caption.
    case timeline
    /// Full-bleed video with the time·place pill and caption box stacked
    /// at the top-left (social-platform safe zone).
    case fullscreen
}

/// Composes the day's clips into a single reel in the chosen style.
/// Both styles keep the blog text on a translucent ink panel over the media.
enum ReelComposer {
    private static let ink = UIColor(red: 0x13 / 255, green: 0x18 / 255, blue: 0x26 / 255, alpha: 1)
    private static let paper = UIColor(red: 0xF4 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)
    private static let gray = UIColor(red: 0x4F / 255, green: 0x56 / 255, blue: 0x63 / 255, alpha: 1)
    private static let purple = UIColor(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255, alpha: 1)

    private struct Segment {
        let moment: Moment
        let start: CMTime
        let duration: CMTime
    }

    static func makeReel(moments: [Moment], blogText: String, style: ReelStyle) async throws -> URL {
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
        var segments: [Segment] = []
        var renderSize = CGSize(width: 1080, height: 1920)
        var isFirst = true
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        for clip in clips {
            let asset = AVURLAsset(url: clip.url)
            let duration = try await asset.load(.duration)
            let range = CMTimeRange(start: .zero, duration: duration)
            if let track = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(range, of: track, at: cursor)

                // Each clip carries its own orientation: camera clips are
                // physically portrait (identity transform), library imports
                // are usually landscape pixels + a rotate transform. Apply
                // the clip's transform, then aspect-fill it into the render
                // frame, keyed to this segment's start time.
                let transform = try await track.load(.preferredTransform)
                let natural = try await track.load(.naturalSize)
                let rect = CGRect(origin: .zero, size: natural).applying(transform)
                let display = CGSize(width: abs(rect.width), height: abs(rect.height))
                if isFirst {
                    renderSize = display
                    isFirst = false
                }
                let originFix = CGAffineTransform(
                    translationX: rect.minX < 0 ? -rect.minX : 0,
                    y: rect.minY < 0 ? -rect.minY : 0
                )
                let fill = max(renderSize.width / display.width, renderSize.height / display.height)
                let centering = CGAffineTransform(
                    translationX: (renderSize.width - display.width * fill) / 2,
                    y: (renderSize.height - display.height * fill) / 2
                )
                let combined = transform
                    .concatenating(originFix)
                    .concatenating(CGAffineTransform(scaleX: fill, y: fill))
                    .concatenating(centering)
                layerInstruction.setTransform(combined, at: cursor)
            }
            if let track = try await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack?.insertTimeRange(range, of: track, at: cursor)
            }
            segments.append(Segment(moment: clip.moment, start: cursor, duration: duration))
            cursor = cursor + duration
        }

        let total = cursor
        let totalSeconds = CMTimeGetSeconds(total)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: total)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let layers: (parent: CALayer, video: CALayer)
        switch style {
        case .timeline:
            layers = timelineLayers(
                segments: segments, renderSize: renderSize,
                totalSeconds: totalSeconds, blogText: blogText
            )
        case .fullscreen:
            layers = fullscreenLayers(
                segments: segments, renderSize: renderSize,
                totalSeconds: totalSeconds, blogText: blogText
            )
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: layers.video, in: layers.parent
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

    // MARK: - Timeline-card style

    private static func timelineLayers(
        segments: [Segment],
        renderSize: CGSize,
        totalSeconds: Double,
        blogText: String
    ) -> (parent: CALayer, video: CALayer) {
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
        let captionStripH = 72 * scale
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

        // Dashed rail + purple dot. The rail's top aligns with the media area
        // (so it never pokes into platform UI like the Instagram story
        // avatar), while its bottom runs slightly past the whole card,
        // caption strip included.
        let railHeight = cardH + 12 * scale
        let railImage = ReelOverlayRenderer.dashedLine(height: railHeight, width: 2 * scale, ink: ink)
        parentLayer.addSublayer(imageLayer(
            railImage,
            origin: CGPoint(x: lineX - scale, y: flipY(mediaTop, railHeight))
        ))

        // Dot (and its time label) sit two dashes below the rail's top.
        let dotDiameter = 14 * scale
        let dotTop = cardTop + 23 * scale
        let dotImage = ReelOverlayRenderer.dot(diameter: dotDiameter, fill: purple, ink: ink, border: border)
        parentLayer.addSublayer(imageLayer(
            dotImage,
            origin: CGPoint(x: lineX - dotDiameter / 2, y: flipY(dotTop, dotDiameter))
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
                maxWidth: cardMinX
            )
            let timeLayer = imageLayer(
                timeImage,
                origin: CGPoint(
                    x: lineX - 10 * scale - timeImage.size.width,
                    y: flipY(dotTop + dotDiameter / 2 - timeImage.size.height / 2, timeImage.size.height)
                )
            )
            setVisibility(timeLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
            parentLayer.addSublayer(timeLayer)

            // Card footer: place on the first line (gray), caption below (ink).
            let stripTop = mediaTop + mediaH
            var cursorY = stripTop + 7 * scale
            let textX = mediaX + 12 * scale
            let textMaxWidth = mediaW - 24 * scale

            let place = truncated(segment.moment.placeName, limit: 40)
            if !place.isEmpty {
                let placeImage = ReelOverlayRenderer.plainText(
                    place,
                    fontSize: 11 * scale,
                    color: gray,
                    maxWidth: textMaxWidth,
                    maxHeight: 16 * scale
                )
                let placeLayer = imageLayer(
                    placeImage,
                    origin: CGPoint(x: textX, y: flipY(cursorY, placeImage.size.height))
                )
                setVisibility(placeLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
                parentLayer.addSublayer(placeLayer)
                cursorY += placeImage.size.height + 4 * scale
            }

            let caption = truncated(segment.moment.caption, limit: 90)
            let captionMaxHeight = stripTop + captionStripH - cursorY - 6 * scale
            if !caption.isEmpty && captionMaxHeight > 12 * scale {
                let captionImage = ReelOverlayRenderer.plainText(
                    caption,
                    fontSize: 13 * scale,
                    color: ink,
                    maxWidth: textMaxWidth,
                    maxHeight: captionMaxHeight
                )
                let captionLayer = imageLayer(
                    captionImage,
                    origin: CGPoint(x: textX, y: flipY(cursorY, captionImage.size.height))
                )
                setVisibility(captionLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
                parentLayer.addSublayer(captionLayer)
            }
        }

        // Blog line lives on the paper below the card — like a note under a
        // polaroid — so it never covers the video.
        let trimmedBlog = blogText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBlog.isEmpty {
            let display = truncated(trimmedBlog, limit: 90)
            let blogImage = ReelOverlayRenderer.plainText(
                display,
                fontSize: 13.5 * scale,
                color: ink,
                maxWidth: W * 0.8,
                maxHeight: max(bottomMargin - 24 * scale, 16 * scale)
            )
            let blogTop = cardTop + cardH + shadowOffset + 12 * scale
            parentLayer.addSublayer(imageLayer(
                blogImage,
                origin: CGPoint(
                    x: (W - blogImage.size.width) / 2,
                    y: flipY(blogTop, blogImage.size.height)
                )
            ))
        }

        return (parentLayer, videoLayer)
    }

    // MARK: - Fullscreen style

    private static func fullscreenLayers(
        segments: [Segment],
        renderSize: CGSize,
        totalSeconds: Double,
        blogText: String
    ) -> (parent: CALayer, video: CALayer) {
        let W = renderSize.width
        let H = renderSize.height
        let scale = W / 390
        func flipY(_ topY: CGFloat, _ height: CGFloat) -> CGFloat { H - topY - height }

        let margin = 20 * scale
        let contentWidth = W - margin * 2
        // Social platforms overlay their own UI on the bottom ~25% and top
        // ~10% of vertical video; overlays sit just below the top margin.
        let topSafeMargin = H * 0.12

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        for segment in segments {
            let pillImage = ReelOverlayRenderer.pill(
                "\(segment.moment.timeLabel) · \(segment.moment.placeName)",
                fontSize: 13 * scale,
                maxWidth: contentWidth,
                ink: ink
            )
            let pillTop = topSafeMargin
            let pillLayer = imageLayer(
                pillImage,
                origin: CGPoint(x: margin, y: flipY(pillTop, pillImage.size.height))
            )
            setVisibility(pillLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
            parentLayer.addSublayer(pillLayer)

            let caption = truncated(segment.moment.caption, limit: 110)
            if !caption.isEmpty {
                let captionImage = ReelOverlayRenderer.captionBox(
                    caption,
                    fontSize: 14 * scale,
                    maxWidth: contentWidth,
                    ink: ink
                )
                let captionTop = pillTop + pillImage.size.height + 10 * scale
                let captionLayer = imageLayer(
                    captionImage,
                    origin: CGPoint(x: margin, y: flipY(captionTop, captionImage.size.height))
                )
                setVisibility(captionLayer, start: segment.start, duration: segment.duration, totalSeconds: totalSeconds)
                parentLayer.addSublayer(captionLayer)
            }
        }

        // Blog line as a compact caption box, bottom-centered just above the
        // platform-UI safe zone (bottom ~25%) — subtitle style, the center
        // of the video stays clear.
        let trimmedBlog = blogText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBlog.isEmpty {
            let display = truncated(trimmedBlog, limit: 90)
            let blogImage = ReelOverlayRenderer.captionBox(
                display,
                fontSize: 13 * scale,
                maxWidth: W * 0.78,
                ink: ink
            )
            let blogTop = H * 0.73 - blogImage.size.height
            parentLayer.addSublayer(imageLayer(
                blogImage,
                origin: CGPoint(
                    x: (W - blogImage.size.width) / 2,
                    y: flipY(blogTop, blogImage.size.height)
                )
            ))
        }

        return (parentLayer, videoLayer)
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

/// Draws overlay images shared by both reel styles: paper-and-ink cards,
/// dashed rail, purple dot, plain text, white pills/boxes, and the
/// translucent blog panel.
enum ReelOverlayRenderer {
    private static func font(_ size: CGFloat) -> UIFont {
        let choice = HLFontChoice.current
        let scaled = size * choice.sizeScale
        switch choice {
        case .kwonjungae:
            return UIFont(name: "Together-KwonJungae", size: scaled)
                ?? UIFont.boldSystemFont(ofSize: scaled)
        case .typewriter:
            return UIFont(name: "AmericanTypewriter-Bold", size: scaled)
                ?? UIFont.boldSystemFont(ofSize: scaled)
        case .system:
            return UIFont.boldSystemFont(ofSize: scaled)
        }
    }

    private static func lineWidth(_ fontSize: CGFloat) -> CGFloat {
        max(fontSize * 0.14, 2)
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

    /// Multiline white rounded box (ink border, ink text). Text wraps within
    /// maxWidth.
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
