import AppKit
import SwiftUI

@main
struct FocuswardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = FocuswardModel.shared

    var body: some Scene {
        Window("Focusward", id: "main") {
            MainWindowContent(model: model, appDelegate: appDelegate)
        }
        .defaultSize(width: 880, height: 660)

        MenuBarExtra {
            MenuBarContentView(showMainWindow: appDelegate.showMainWindow)
                .environmentObject(model)
        } label: {
            Image(systemName: model.isProtectionActive ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

private struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: FocuswardModel
    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .environmentObject(model)
            .frame(
                minWidth: 760,
                idealWidth: 880,
                minHeight: 600,
                idealHeight: 660
            )
            .onAppear {
                appDelegate.openMainWindow = {
                    openWindow(id: "main")
                }
            }
    }
}
