import AppKit
import SwiftUI

@main
struct FocuswardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = FocuswardModel.shared
    @State private var selectedSection: FocuswardSection? = .focusSession

    var body: some Scene {
        Window("Focusward", id: "main") {
            MainWindowContent(model: model, appDelegate: appDelegate, selectedSection: $selectedSection)
        }
        .defaultSize(width: 880, height: 660)
        .commands {
            SectionCommands(selectedSection: $selectedSection)
        }

        MenuBarExtra {
            MenuBarContentView(showMainWindow: appDelegate.showMainWindow)
                .environmentObject(model)
        } label: {
            Image(model.isProtectionActive ? "MenuBarIconOn" : "MenuBarIconOff")
                .accessibilityLabel(model.isProtectionActive ? "Focusward, protection on" : "Focusward, protection off")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: FocuswardModel
    let appDelegate: AppDelegate
    @Binding var selectedSection: FocuswardSection?

    var body: some View {
        ContentView(selectedSection: $selectedSection)
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
