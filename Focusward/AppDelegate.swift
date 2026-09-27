import AppKit

enum QuitPolicy {
    enum Decision: Equatable {
        case allow
        case refuse(title: String, message: String)
    }

    // A session or Daily Limits must not stop a logout, restart, or shutdown.
    private static let systemQuitReasons = Set(
        [kAELogOut, kAEReallyLogOut, kAEShowRestartDialog, kAERestart, kAEShowShutdownDialog, kAEShutDown]
            .map { OSType($0) }
    )

    static func decision(
        quitReason: OSType?,
        isSessionActive: Bool,
        isDailyLimitsActive: Bool
    ) -> Decision {
        if let quitReason, systemQuitReasons.contains(quitReason) {
            return .allow
        }
        if isSessionActive {
            return .refuse(
                title: "A focus session is active",
                message: "To quit Focusward, end the session early in the Focus Session tab first."
            )
        }
        if isDailyLimitsActive {
            return .refuse(
                title: "Daily Limits are active",
                message: "To quit Focusward, turn off Daily Limits in the Daily Limits tab first."
            )
        }
        return .allow
    }
}

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

        let quitReason = NSAppleEventManager.shared().currentAppleEvent?
            .attributeDescriptor(forKeyword: kAEQuitReason)?
            .enumCodeValue
        let decision = QuitPolicy.decision(
            quitReason: quitReason,
            isSessionActive: model.isSessionActive,
            isDailyLimitsActive: model.dailyLimits.isActive
        )
        guard case .refuse(let title, let message) = decision else {
            return .terminateNow
        }

        sender.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
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

    private var isRunningTestsOrPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return NSClassFromString("XCTestCase") != nil
            || environment.keys.contains { $0.hasPrefix("XCTest") }
            || environment["XCInjectBundleInto"] != nil
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
