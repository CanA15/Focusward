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
        model.persistStateForTermination()
        guard !isSystemQuit else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .informational
        if model.isSessionActive {
            alert.messageText = "A focus session is active"
            alert.informativeText = "To quit Focusward, end the session early in the Focus Session tab first."
        } else if model.dailyLimits.isActive {
            alert.messageText = "Daily Limits are active"
            alert.informativeText = "To quit Focusward, turn off Daily Limits in the Daily Limits tab first."
        } else {
            return .terminateNow
        }

        sender.activate(ignoringOtherApps: true)
        alert.addButton(withTitle: "Stay Focused")
        alert.runModal()
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

    // A session or Daily Limits must not stop a logout, restart, or shutdown.
    private var isSystemQuit: Bool {
        guard
            let reason = NSAppleEventManager.shared().currentAppleEvent?
                .attributeDescriptor(forKeyword: kAEQuitReason)?
                .enumCodeValue
        else {
            return false
        }

        return [kAELogOut, kAEReallyLogOut, kAEShowRestartDialog, kAERestart, kAEShowShutdownDialog, kAEShutDown]
            .map { OSType($0) }
            .contains(reason)
    }

    private var isRunningTestsOrPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return NSClassFromString("XCTestCase") != nil
            || environment.keys.contains { $0.hasPrefix("XCTest") }
            || environment["XCInjectBundleInto"] != nil
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
