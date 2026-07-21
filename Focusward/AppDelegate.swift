import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let model = FocuswardModel.shared
        guard model.isSessionActive else {
            return .terminateNow
        }

        sender.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "A Focusward session is active"
        alert.informativeText = "Ordinary quitting is paused until the session ends. You can begin a cancelable 90-second early-end request instead."
        alert.addButton(withTitle: "Stay Focused")
        alert.addButton(withTitle: "Request Early End")

        if alert.runModal() == .alertSecondButtonReturn {
            model.requestEarlyEnd()
        }

        return .terminateCancel
    }
}
