import CoreText
import SwiftUI
import WidgetKit

@main
struct DailoggerWidgetBundle: WidgetBundle {
    init() {
        // Register the bundled handwriting font for widget rendering.
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Widget {
        StreakWidget()
    }
}
