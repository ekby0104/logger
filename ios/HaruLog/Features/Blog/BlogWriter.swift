import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct BlogResult {
    let title: String
    let body: String
    let isAIGenerated: Bool
}

/// Turns a day's moments into a diary entry.
/// Uses the on-device Apple Intelligence model when available
/// (iOS 26+, supported hardware); otherwise composes from a template.
enum BlogWriter {
    static func write(for moments: [Moment], date: Date) async -> BlogResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                if let result = try? await writeWithAppleIntelligence(moments: moments, date: date) {
                    return result
                }
            }
        }
        #endif
        return template(moments: moments, date: date)
    }

    // MARK: - Template fallback

    private static func template(moments: [Moment], date: Date) -> BlogResult {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMM d"
        let dayName = formatter.string(from: date)

        let sorted = moments.sorted { $0.createdAt < $1.createdAt }
        let moodCounts = Dictionary(grouping: sorted, by: { $0.mood }).mapValues(\.count)
        let topMood = moodCounts.max { $0.value < $1.value }?.key ?? .calm

        var lines: [String] = []
        lines.append(
            "\(dayName). I captured \(sorted.count) little moments today, " +
            "and looking back, the day felt mostly \(topMood.rawValue.lowercased())."
        )
        for moment in sorted {
            lines.append(
                "At \(moment.timeLabel), \"\(moment.title)\" at \(moment.placeName) — \(moment.caption)"
            )
        }
        lines.append("That was my day — \(sorted.count) clips of ordinary life worth keeping.")

        return BlogResult(
            title: "\(dayName) — a \(topMood.rawValue.lowercased()) day",
            body: lines.joined(separator: "\n\n"),
            isAIGenerated: false
        )
    }
}

// MARK: - Apple Intelligence path

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable
private struct GeneratedBlog {
    @Guide(description: "A warm, personal diary title. Max 40 characters. No quotation marks.")
    var title: String

    @Guide(description: """
        The diary entry: 4-6 sentences, first person, past tense, warm and reflective, \
        weaving the moments into one flowing narrative. No lists or headings.
        """)
    var body: String
}

@available(iOS 26.0, *)
extension BlogWriter {
    static func writeWithAppleIntelligence(moments: [Moment], date: Date) async throws -> BlogResult {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"

        let momentLines = moments
            .sorted { $0.createdAt < $1.createdAt }
            .map {
                "- \($0.timeLabel) | \($0.title) | mood: \($0.mood.rawValue) | " +
                "place: \($0.placeName) | note: \($0.caption)"
            }
            .joined(separator: "\n")

        let session = LanguageModelSession(
            instructions: """
            You turn a list of short video moments from someone's day into a warm, \
            first-person diary entry, as if they wrote it themselves at night. \
            Write naturally and concretely. Never invent events that are not in the list.
            """
        )
        let prompt = """
        Date: \(formatter.string(from: date))
        Today's moments:
        \(momentLines)
        """

        let response = try await session.respond(to: prompt, generating: GeneratedBlog.self)
        return BlogResult(
            title: response.content.title,
            body: response.content.body,
            isAIGenerated: true
        )
    }
}

#endif
