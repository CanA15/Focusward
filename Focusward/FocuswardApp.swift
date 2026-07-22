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

        MenuBarExtra {
            MenuBarContentView(showMainWindow: appDelegate.showMainWindow)
                .environmentObject(model)
        } label: {
            FocuswardMenuBarMark()
                .frame(width: 18, height: 18)
                .opacity(model.isSessionActive ? 1 : 0.72)
                .accessibilityLabel(
                    model.isSessionActive ? "Focusward, session active" : "Focusward"
                )
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

private struct FocuswardMenuBarMark: View {
    var body: some View {
        FocuswardGlyphShape()
            .fill(.primary, style: FillStyle(eoFill: true))
    }
}

private struct FocuswardGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to: point(0.5, 0.03))
        path.addCurve(
            to: point(0.9, 0.22),
            control1: point(0.64, 0.1),
            control2: point(0.79, 0.15)
        )
        path.addLine(to: point(0.9, 0.51))
        path.addCurve(
            to: point(0.5, 0.97),
            control1: point(0.9, 0.75),
            control2: point(0.73, 0.9)
        )
        path.addCurve(
            to: point(0.1, 0.51),
            control1: point(0.27, 0.9),
            control2: point(0.1, 0.75)
        )
        path.addLine(to: point(0.1, 0.22))
        path.addCurve(
            to: point(0.5, 0.03),
            control1: point(0.21, 0.17),
            control2: point(0.36, 0.1)
        )
        path.closeSubpath()

        path.move(to: point(0.31, 0.75))
        path.addLine(to: point(0.31, 0.43))
        path.addLine(to: point(0.5, 0.29))
        path.addLine(to: point(0.69, 0.43))
        path.addLine(to: point(0.69, 0.75))
        path.addLine(to: point(0.59, 0.65))
        path.addLine(to: point(0.59, 0.48))
        path.addLine(to: point(0.5, 0.41))
        path.addLine(to: point(0.41, 0.48))
        path.addLine(to: point(0.41, 0.65))
        path.addLine(to: point(0.5, 0.86))
        path.closeSubpath()
        return path
    }
}
