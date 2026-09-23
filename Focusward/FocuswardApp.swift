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
        .defaultSize(width: 720, height: 780)
        .windowToolbarStyle(.unified(showsTitle: false))

        MenuBarExtra {
            MenuBarContentView(showMainWindow: appDelegate.showMainWindow)
                .environmentObject(model)
        } label: {
            Image(systemName: model.isProtectionActive ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.controlActiveState) private var controlActiveState
    @ObservedObject var model: FocuswardModel
    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .environmentObject(model)
            .frame(
                minWidth: 640,
                idealWidth: 720,
                minHeight: 680,
                idealHeight: 780
            )
            .onAppear {
                appDelegate.openMainWindow = {
                    openWindow(id: "main")
                }
                model.setMainWindowFocused(controlActiveState == .key)
            }
            .onChange(of: controlActiveState) { _, newState in
                model.setMainWindowFocused(newState == .key)
            }
            .onDisappear { model.setMainWindowFocused(false) }
    }
}
