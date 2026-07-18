import CoreText
import Foundation

/// Registers bundled .ttf fonts at runtime. The app uses a generated
/// Info.plist, which can't express the UIAppFonts array — runtime
/// registration via CoreText works without it.
enum FontLoader {
    static func registerBundledFonts(bundle: Bundle = .main) {
        var urls: [URL] = []
        for ext in ["ttf", "otf"] {
            urls += bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
            urls += bundle.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? []
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
