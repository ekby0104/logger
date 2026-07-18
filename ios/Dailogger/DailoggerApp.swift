import SwiftUI
import SwiftData

@main
struct DailoggerApp: App {
    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Moment.self, DailyLog.self])
    }
}
