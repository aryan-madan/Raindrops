
import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApplication.shared.setActivationPolicy(.accessory)
        return false
    }
}

@main
struct Raindrops: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var store = Store()

    var body: some Scene {
        Window("Raindrops", id: "mainWindow") {
            Home()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onAppear { store.boot() }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
        
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            if let url = Bundle.module.url(forResource: "Logo", withExtension: "svg"),
               let nsImage = NSImage(contentsOf: url) {
                let resized = nsImage
                let _ = resized.size = NSSize(width: 16, height: 16)
                Image(nsImage: resized)
            }
        }
        .menuBarExtraStyle(.window)
    }
}