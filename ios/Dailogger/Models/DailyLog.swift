import Foundation
import SwiftData

@Model
final class DailyLog {
    var date: Date
    var clipCount: Int
    var isBlogReady: Bool
    var blogTitle: String?
    var blogText: String?
    var blogIsAI: Bool?

    init(date: Date, clipCount: Int, isBlogReady: Bool = true) {
        self.date = date
        self.clipCount = clipCount
        self.isBlogReady = isBlogReady
    }

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
