import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Dailogger design tokens (from 하루로그-wireframe.dc.html)
enum HL {
    static let ink = Color(hex: 0x131826)
    static let blue = Color(hex: 0x0967F5)
    static let purple = Color(hex: 0xA855F7)
    static let paper = Color(hex: 0xF4F5F7)
    static let placeholder = Color(hex: 0xE9EBF0)
    static let muted = Color(hex: 0x9FA5B2)
    static let gray = Color(hex: 0x4F5663)
    static let red = Color(hex: 0xDC0A0A)
    static let camBackground = Color(hex: 0x20242F)
    static let calEmpty = Color(hex: 0xF1F3F7)
}

/// User-selectable app typeface. Stored in UserDefaults ("appFont") and
/// mirrored into the app group so the widget follows along.
enum HLFontChoice: String, CaseIterable {
    case kwonjungae
    case typewriter
    case system

    static let storageKey = "appFont"

    static var current: HLFontChoice {
        HLFontChoice(
            rawValue: UserDefaults.standard.string(forKey: storageKey) ?? ""
        ) ?? .kwonjungae
    }
}

extension Font {
    /// Display face for the chosen typeface (bold role).
    static func hl(_ size: CGFloat) -> Font {
        switch HLFontChoice.current {
        case .kwonjungae:
            return .custom("Together-KwonJungae", size: size)
        case .typewriter:
            return .custom("AmericanTypewriter-Bold", size: size)
        case .system:
            return .system(size: size, weight: .bold)
        }
    }

    /// Body face for the chosen typeface (regular role).
    static func hlRegular(_ size: CGFloat) -> Font {
        switch HLFontChoice.current {
        case .kwonjungae:
            return .custom("Together-KwonJungae", size: size)
        case .typewriter:
            return .custom("AmericanTypewriter", size: size)
        case .system:
            return .system(size: size, weight: .regular)
        }
    }
}
