import AppKit
import Foundation

struct SafariTabSnapshot {
    let windowIndex: Int
    let tabIndex: Int
    let url: String
}

enum SafariAutomationError: LocalizedError {
    case compilation(String)
    case execution(String)
    case malformedResult

    var errorDescription: String? {
        switch self {
        case .compilation(let message):
            "Could not prepare Safari automation: \(message)"
        case .execution(let message):
            "Safari automation failed: \(message)"
        case .malformedResult:
            "Safari returned an unexpected tab list."
        }
    }
}

@MainActor
final class SafariAutomation {
    func tabs() throws -> [SafariTabSnapshot] {
        let source = """
        if application "Safari" is not running then return {}

        set tabSnapshots to {}
        tell application "Safari"
            repeat with windowIndex from 1 to count of windows
                repeat with tabIndex from 1 to count of tabs of window windowIndex
                    try
                        set tabURL to URL of tab tabIndex of window windowIndex
                        if tabURL is missing value then set tabURL to ""
                        set end of tabSnapshots to {windowIndex, tabIndex, tabURL as text}
                    end try
                end repeat
            end repeat
        end tell
        return tabSnapshots
        """

        let result = try execute(source)
        guard result.descriptorType == typeAEList else {
            throw SafariAutomationError.malformedResult
        }

        var snapshots: [SafariTabSnapshot] = []
        for offset in 0..<result.numberOfItems {
            let index = offset + 1
            guard
                let row = result.atIndex(index),
                row.descriptorType == typeAEList,
                row.numberOfItems == 3,
                let url = row.atIndex(3)?.stringValue
            else {
                continue
            }

            snapshots.append(
                SafariTabSnapshot(
                    windowIndex: Int(row.atIndex(1)?.int32Value ?? 0),
                    tabIndex: Int(row.atIndex(2)?.int32Value ?? 0),
                    url: url
                )
            )
        }

        return snapshots
    }

    @discardableResult
    func redirect(_ tab: SafariTabSnapshot, to destination: URL) throws -> Bool {
        let expectedURL = appleScriptLiteral(tab.url)
        let destinationURL = appleScriptLiteral(destination.absoluteString)

        let source = """
        if application "Safari" is not running then return false

        tell application "Safari"
            if (count of windows) < \(tab.windowIndex) then return false
            if (count of tabs of window \(tab.windowIndex)) < \(tab.tabIndex) then return false

            set candidateTab to tab \(tab.tabIndex) of window \(tab.windowIndex)
            if (URL of candidateTab as text) is \(expectedURL) then
                set URL of candidateTab to \(destinationURL)
                return true
            end if
        end tell
        return false
        """

        return try execute(source).booleanValue
    }

    private func execute(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw SafariAutomationError.compilation("Unknown compilation error")
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? errorInfo.description
            let number = errorInfo[NSAppleScript.errorNumber] as? Int

            if number == -1743 {
                throw SafariAutomationError.execution(
                    "Permission was denied. Allow Focusward to control Safari in Privacy & Security → Automation."
                )
            }

            throw SafariAutomationError.execution(message)
        }

        return result
    }

    private func appleScriptLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
