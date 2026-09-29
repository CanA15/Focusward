import AppKit

struct SafariTabSnapshot: Equatable, Sendable {
    let windowIndex: Int
    let tabIndex: Int
    let url: String
}

enum SafariAutomationError: LocalizedError {
    case execution(String)
    case malformedResult

    var errorDescription: String? {
        switch self {
        case .execution(let message):
            "Safari automation failed: \(message)"
        case .malformedResult:
            "Safari returned an unexpected tab list."
        }
    }
}

// Apple Events wait for Safari, and a permission prompt can hold a request for a long time.
// The actor runs on its own queue, so this waiting never blocks the main thread or the shared thread pool.
actor SafariAutomation {
    private static let tabClass: DescType = 0x6254_6162 // 'bTab'
    private static let urlProperty: DescType = 0x7055_524C // 'pURL'
    private static let requestError = SafariAutomationError.execution("Could not build a Safari request.")

    private let queue = DispatchSerialQueue(label: "app.focusward.local.safari-automation")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    func tabs() throws -> [SafariTabSnapshot] {
        guard let safari = runningSafari() else { return [] }
        do {
            return try Self.snapshots(fromWindowTabURLs: windowTabURLs(in: safari))
        } catch let error as NSError where Self.isSafariGone(error) {
            return []
        } catch {
            throw Self.automationError(error)
        }
    }

    @discardableResult
    func redirect(_ tab: SafariTabSnapshot, to destination: URL) throws -> Bool {
        guard let safari = runningSafari() else { return false }
        do {
            let window = try Self.windowSpecifier(at: tab.windowIndex)
            let url = try Self.urlProperty(of: Self.tabSpecifier(at: tab.tabIndex, in: window))

            // The tab can change after the scan. Only a tab that still shows the scanned URL moves.
            guard try send(kAEGetData, [keyDirectObject: url], to: safari).stringValue == tab.url else {
                return false
            }
            let destinationURL = NSAppleEventDescriptor(string: destination.absoluteString)
            try send(kAESetData, [keyDirectObject: url, keyAEData: destinationURL], to: safari)
            return true
        } catch let error as NSError where Self.isMissingObject(error) || Self.isSafariGone(error) {
            return false
        } catch {
            throw Self.automationError(error)
        }
    }

    static func snapshots(fromWindowTabURLs reply: NSAppleEventDescriptor) throws -> [SafariTabSnapshot] {
        guard reply.descriptorType == typeAEList else { throw SafariAutomationError.malformedResult }

        var snapshots: [SafariTabSnapshot] = []
        for windowIndex in stride(from: 1, through: reply.numberOfItems, by: 1) {
            guard let tabURLs = reply.atIndex(windowIndex), tabURLs.descriptorType == typeAEList else {
                throw SafariAutomationError.malformedResult
            }
            for tabIndex in stride(from: 1, through: tabURLs.numberOfItems, by: 1) {
                // A tab without a page replies with "missing value" instead of a URL.
                guard
                    let tabURL = tabURLs.atIndex(tabIndex),
                    tabURL.descriptorType != typeType,
                    let url = tabURL.stringValue
                else {
                    continue
                }
                snapshots.append(SafariTabSnapshot(windowIndex: windowIndex, tabIndex: tabIndex, url: url))
            }
        }
        return snapshots
    }

    private func windowTabURLs(in safari: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        let everyWindow = try Self.specifier(
            class: cWindow,
            form: formAbsolutePosition,
            data: Self.every(),
            in: .null()
        )
        do {
            return try send(kAEGetData, [keyDirectObject: Self.urlOfEveryTab(in: everyWindow)], to: safari)
        } catch let error as NSError where Self.isMissingObject(error) {
            // A window without tabs, such as the Settings window, fails the request for all windows.
            return try windowTabURLsWindowByWindow(in: safari)
        }
    }

    private func windowTabURLsWindowByWindow(in safari: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        let windowClass = NSAppleEventDescriptor(typeCode: cWindow)
        let count = try send(kAECountElements, [keyDirectObject: .null(), keyAEObjectClass: windowClass], to: safari)
        let windows = NSAppleEventDescriptor.list()
        for index in stride(from: 1, through: Int(count.int32Value), by: 1) {
            let urlOfEveryTab = try Self.urlOfEveryTab(in: Self.windowSpecifier(at: index))
            do {
                windows.insert(try send(kAEGetData, [keyDirectObject: urlOfEveryTab], to: safari), at: 0)
            } catch let error as NSError where Self.isMissingObject(error) {
                windows.insert(NSAppleEventDescriptor.list(), at: 0)
            }
        }
        return windows
    }

    // A request to a process identifier never launches Safari.
    private func runningSafari() -> NSAppleEventDescriptor? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari")
            .first { !$0.isTerminated }
            .map { NSAppleEventDescriptor(processIdentifier: $0.processIdentifier) }
    }

    @discardableResult
    private func send(
        _ eventID: AEEventID,
        _ parameters: [AEKeyword: NSAppleEventDescriptor],
        to safari: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: kAECoreSuite,
            eventID: eventID,
            targetDescriptor: safari,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        for (keyword, value) in parameters {
            event.setParam(value, forKeyword: keyword)
        }

        let reply = try event.sendEvent(options: [.waitForReply, .canInteract], timeout: 30)
        if let errorNumber = reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value, errorNumber != 0 {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errorNumber))
        }
        return reply.paramDescriptor(forKeyword: keyDirectObject) ?? NSAppleEventDescriptor.null()
    }

    private static func specifier(
        class desiredClass: DescType,
        form: Int,
        data: NSAppleEventDescriptor,
        in container: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: desiredClass), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(form)), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(data, forKeyword: AEKeyword(keyAEKeyData))
        guard let specifier = record.coerce(toDescriptorType: typeObjectSpecifier) else { throw requestError }
        return specifier
    }

    private static func windowSpecifier(at index: Int) throws -> NSAppleEventDescriptor {
        let position = NSAppleEventDescriptor(int32: Int32(index))
        return try specifier(class: cWindow, form: formAbsolutePosition, data: position, in: .null())
    }

    private static func tabSpecifier(
        at index: Int,
        in window: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let position = NSAppleEventDescriptor(int32: Int32(index))
        return try specifier(class: tabClass, form: formAbsolutePosition, data: position, in: window)
    }

    private static func urlOfEveryTab(in windows: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        try urlProperty(of: specifier(class: tabClass, form: formAbsolutePosition, data: every(), in: windows))
    }

    private static func urlProperty(of tab: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        let property = NSAppleEventDescriptor(typeCode: urlProperty)
        return try specifier(class: cProperty, form: formPropertyID, data: property, in: tab)
    }

    private static func every() throws -> NSAppleEventDescriptor {
        let all = withUnsafeBytes(of: OSType(kAEAll)) {
            NSAppleEventDescriptor(descriptorType: typeAbsoluteOrdinal, bytes: $0.baseAddress, length: $0.count)
        }
        guard let all else { throw requestError }
        return all
    }

    private static func isSafariGone(_ error: NSError) -> Bool {
        error.domain == NSOSStatusErrorDomain && [procNotFound, connectionInvalid].contains(error.code)
    }

    private static func isMissingObject(_ error: NSError) -> Bool {
        error.domain == NSOSStatusErrorDomain && [errAENoSuchObject, errAEIllegalIndex].contains(error.code)
    }

    private static func automationError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == NSOSStatusErrorDomain else { return error }
        if nsError.code == errAEEventNotPermitted {
            return SafariAutomationError.execution(
                "Permission was denied. Allow Focusward to control Safari in Privacy & Security → Automation."
            )
        }
        return SafariAutomationError.execution(nsError.localizedDescription)
    }
}
