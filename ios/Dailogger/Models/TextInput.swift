import Foundation

/// Cleans user-entered text before it is stored or rendered into reels:
/// strips invisible/bidirectional control characters that can spoof or
/// corrupt display, drops raw control codes, and caps the length.
/// Emoji (including ZWJ sequences) pass through untouched.
enum TextInput {
    static let captionLimit = 150
    static let blogTitleLimit = 60
    static let blogBodyLimit = 300

    private static let blockedScalars: Set<UInt32> = {
        var set: Set<UInt32> = [
            0x200B, // zero-width space
            0x2060, // word joiner
            0xFEFF, // BOM / zero-width no-break space
            0x200E, 0x200F, 0x061C // bidi direction marks
        ]
        for value in 0x202A...0x202E { set.insert(UInt32(value)) } // bidi embeds/overrides
        for value in 0x2066...0x2069 { set.insert(UInt32(value)) } // bidi isolates
        return set
    }()

    static func sanitize(_ text: String, limit: Int, allowNewlines: Bool = false) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if blockedScalars.contains(scalar.value) { continue }
            if scalar.properties.generalCategory == .control {
                // Raw control codes are dropped; newlines survive only
                // where the field is multi-line.
                if scalar == "\n" && allowNewlines {
                    scalars.append(scalar)
                }
                continue
            }
            scalars.append(scalar)
        }
        var result = String(scalars)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count > limit {
            result = String(result.prefix(limit))
        }
        return result
    }
}
