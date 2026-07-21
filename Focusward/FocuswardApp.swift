import AppKit
import SwiftUI

@main
struct FocuswardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = FocuswardModel.shared

    var body: some Scene {
        Window("Focusward", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 560, minHeight: 620)
                .onOpenURL { _ in
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
                }
        }
        .defaultSize(width: 600, height: 680)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.isSessionActive ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)
    }
}
