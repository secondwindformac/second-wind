// Second Wind Creator — entry point.
#if os(macOS)
import SwiftUI
import AppKit

@main
struct CreatorApp: App {
    @StateObject private var state = AppState()

    init() {
        // Behave like a normal app even when launched as a bare binary
        // (swift run) during development.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup(L10n.appTitle) {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 600, idealWidth: 600, minHeight: 560, idealHeight: 560)
        }
    }
}
#else
// The SwiftUI app only exists on macOS; keep Linux CI builds of the package
// happy with a stub entry point.
@main
struct CreatorAppStub {
    static func main() {
        print("SecondWindCreator is a macOS app. On Linux, use `seedtool`.")
    }
}
#endif
