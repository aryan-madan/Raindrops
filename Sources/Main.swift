import SwiftUI
import AppKit

@main
struct Raindrops: App {
    @StateObject var store = Store()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            Home()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onAppear { store.boot() }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}