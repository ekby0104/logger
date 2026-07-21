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

    /// Short SNS-caption style, matching the AI output: one punchy line.
    private static func template(moments: [Moment], date: Date) -> BlogResult {
        let dayName = date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let sorted = moments.sorted { $0.createdAt < $1.createdAt }

        let body: String
        if let caption = sorted.first(where: { !$0.caption.isEmpty })?.caption {
            body = String(localized: "\(caption) 🎬 day logged ✨")
        } else {
            body = String(localized: "Today in \(sorted.count) clips, nailed it ✨")
        }

        return BlogResult(
            title: dayName,
            body: body,
            isAIGenerated: false
        )
    }
}

// MARK: - Apple Intelligence path

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable
private struct GeneratedBlog {
    @Guide(description: "A catchy title. Max 5 words. No quotation marks.")
    var title: String

    @Guide(description: """
        One punchy social-media caption for the day. STRICTLY 10 words or \
        fewer. Casual, trendy Gen-Z voice. At most two emojis. \
        No hashtags, no lists, no line breaks.
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
                let note = $0.caption.isEmpty ? "(no note)" : $0.caption
                return "- \($0.timeLabel) | place: \($0.placeName) | note: \(note)"
            }
            .joined(separator: "\n")

        let wantsKorean = Locale.preferredLanguages.first?.hasPrefix("ko") ?? false
        let languageRule = wantsKorean
            ? "Write in Korean: casual, trendy MZ/SNS tone (짧은 반말, 인스타 캡션 느낌)."
            : "Write in English: casual, trendy social-caption tone."
        let session = LanguageModelSession(
            instructions: """
            You turn a list of short video moments from someone's day into ONE \
            ultra-short social-media caption they could post as-is. \
            Hard limit: 10 words or fewer. First person, playful, at most two \
            emojis. Never invent events that are not in the list. \
            \(languageRule)
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
