import Foundation
import SwiftData

enum Mood: String, CaseIterable, Codable, Hashable {
    case fresh = "Fresh"
    case calm = "Calm"
    case happy = "Happy"
    case peaceful = "Peaceful"
    case moved = "Moved"
    case proud = "Proud"
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

    init(
        id: UUID = UUID(),
        createdAt: Date,
        title: String,
        caption: String,
        mood: Mood,
        duration: TimeInterval,
        placeName: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.caption = caption
        self.moodRaw = mood.rawValue
        self.duration = duration
        self.placeName = placeName
    }

    var mood: Mood {
        get { Mood(rawValue: moodRaw) ?? .calm }
        set { moodRaw = newValue.rawValue }
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: createdAt)
    }

    var durationLabel: String {
        let seconds = Int(duration)
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
