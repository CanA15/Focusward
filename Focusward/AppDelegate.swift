import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let showMainWindowNotification = Notification.Name(
        "app.focusward.local.showMainWindow"
    )

    var openMainWindow: (() -> Void)?
    private var isDuplicateInstance = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !isRunningTestsOrPreviews else { return }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existingInstance = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }
            .min { ($0.launchDate ?? .distantFuture) < ($1.launchDate ?? .distantFuture) }

        if let existingInstance {
            isDuplicateInstance = true
            DistributedNotificationCenter.default().postNotificationName(
                Self.showMainWindowNotification,
                object: nil,
                deliverImmediately: true
            )
            existingInstance.activate(options: [.activateAllWindows])
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowMainWindow),
            name: Self.showMainWindowNotification,
            object: nil
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard
            !isDuplicateInstance,
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !isDuplicateInstance else { return }
        showMainWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isDuplicateInstance {
            return .terminateNow
        }

        let model = FocuswardModel.shared
        guard model.isSessionActive else {
            return .terminateNow
        }

        sender.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "A Focusward session is active"
        alert.informativeText = "Ordinary quitting is paused until the session ends. You can begin a cancelable early-end request that advances only while Focusward is in front."
        alert.addButton(withTitle: "Stay Focused")
        alert.addButton(withTitle: "Request Early End")

        if alert.runModal() == .alertSecondButtonReturn {
            model.requestEarlyEnd()
        }

        return .terminateCancel
    }

    @objc private func handleShowMainWindow(_ notification: Notification) {
        showMainWindow()
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.title == "Focusward" }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }

    private var isRunningTestsOrPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return NSClassFromString("XCTestCase") != nil
            || environment.keys.contains { $0.hasPrefix("XCTest") }
            || environment["XCInjectBundleInto"] != nil
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
