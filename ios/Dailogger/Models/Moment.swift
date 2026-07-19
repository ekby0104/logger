import Foundation
import SwiftData

enum Mood: String, CaseIterable, Codable, Hashable {
    case fresh = "Fresh"
    case calm = "Calm"
    case happy = "Happy"
    case peaceful = "Peaceful"
    case moved = "Moved"
    case proud = "Proud"

    /// Localized label for UI; rawValue stays English for storage and AI prompts.
    var displayName: String {
        switch self {
        case .fresh: return String(localized: "Fresh")
        case .calm: return String(localized: "Calm")
        case .happy: return String(localized: "Happy")
        case .peaceful: return String(localized: "Peaceful")
        case .moved: return String(localized: "Moved")
        case .proud: return String(localized: "Proud")
        }
    }
}

@Model
final class Moment {
    var id: UUID
    var createdAt: Date
    var title: String
    var caption: String
    var moodRaw: String
    var duration: TimeInterval
    var placeName: String
    var latitude: Double?
    var longitude: Double?
    var videoFileName: String?
    var thumbnailFileName: String?

    init(
        id: UUID = UUID(),
        createdAt: Date,
        title: String,
        caption: String,
        mood: Mood,
        duration: TimeInterval,
        placeName: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        videoFileName: String? = nil,
        thumbnailFileName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.caption = caption
        self.moodRaw = mood.rawValue
        self.duration = duration
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.videoFileName = videoFileName
        self.thumbnailFileName = thumbnailFileName
    }

    var videoURL: URL? { MediaStore.url(fileName: videoFileName) }
    var thumbnailURL: URL? { MediaStore.url(fileName: thumbnailFileName) }

    var mood: Mood {
        get { Mood(rawValue: moodRaw) ?? .calm }
        set { moodRaw = newValue.rawValue }
    }

    // DateFormatter creation is expensive; reuse one per format.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var timeLabel: String {
        Self.timeFormatter.string(from: createdAt)
    }

    var durationLabel: String {
        let seconds = max(Int(duration.rounded()), 1)
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
