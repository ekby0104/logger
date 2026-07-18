import CoreText
import Foundation

/// Registers bundled .ttf fonts at runtime. The app uses a generated
/// Info.plist, which can't express the UIAppFonts array — runtime
/// registration via CoreText works without it.
enum FontLoader {
    static func registerBundledFonts(bundle: Bundle = .main) {
        var urls: [URL] = []
        urls += bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        urls += bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
