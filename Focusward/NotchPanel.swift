import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var notchHeight: CGFloat = 0

    let showMainWindow: () -> Void
    private let model: FocuswardModel
    private var panel: NSPanel?
    private var breakCount = 0
    private var isEnabled = false
    private var outsideClickMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(model: FocuswardModel, showMainWindow: @escaping () -> Void) {
        self.model = model
        self.showMainWindow = showMainWindow

        // A published value arrives before the model stores it, so pass the values on.
        model.$dailyLimits
            .map(\.sitesOnBreak.count)
            .removeDuplicates()
            .combineLatest(model.$showsNotchBreakTimer)
            .sink { [weak self] breakCount, isEnabled in
                MainActor.assumeIsolated {
                    self?.breakCount = breakCount
                    self?.isEnabled = isEnabled
                    self?.updatePanel()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.updatePanel() }
            }
            .store(in: &cancellables)
    }

    func toggleExpanded() {
        setExpanded(!isExpanded)
    }

    func openMainWindow() {
        setExpanded(false)
        showMainWindow()
    }

    private func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        if expanded, outsideClickMonitor == nil {
            // A global monitor receives only clicks in other apps, so a click in the panel keeps it open.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.setExpanded(false) }
            }
        } else if !expanded, let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        updatePanel()
    }

    private func updatePanel() {
        guard
            isEnabled,
            breakCount > 0,
            let notch = NSScreen.screens.lazy.compactMap(\.notchFrame).first
        else {
            if isExpanded {
                setExpanded(false)
            }
            panel?.orderOut(nil)
            return
        }

        notchHeight = notch.height
        let panel = panel ?? makePanel()
        // One row for each break and one row for Open Focusward.
        panel.setFrame(
            NotchLayout.panelFrame(notch: notch, isExpanded: isExpanded, rowCount: breakCount + 1),
            display: true
        )
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // The panel must be above the menu bar and below menus.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView = NotchHostingView(
            rootView: NotchView(controller: self).environmentObject(model)
        )
        self.panel = panel
        return panel
    }
}

private extension NSScreen {
    var notchFrame: CGRect? {
        NotchLayout.notchFrame(
            screenFrame: frame,
            topInset: safeAreaInsets.top,
            leftAreaWidth: auxiliaryTopLeftArea?.width,
            rightAreaWidth: auxiliaryTopRightArea?.width
        )
    }
}

// The panel never becomes active, so the first click must operate a control.
private final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct NotchView: View {
    @EnvironmentObject private var model: FocuswardModel
    @ObservedObject var controller: NotchPanelController

    var body: some View {
        VStack(spacing: 0) {
            Button(action: controller.toggleExpanded) {
                HStack(spacing: 0) {
                    Image(systemName: "cup.and.saucer.fill")
                        .frame(width: NotchLayout.earWidth)
                    Spacer(minLength: 0)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(countdownText(seconds: secondsLeft(for: model.dailyLimits.nextBreakToEnd, at: context.date)))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(width: NotchLayout.earWidth)
                    }
                }
                .frame(height: controller.notchHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(controller.isExpanded ? "Hide break options" : "Show break options")

            if controller.isExpanded {
                VStack(spacing: 0) {
                    ForEach(model.dailyLimits.sitesOnBreak) { site in
                        HStack {
                            Text(site.domain)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(countdownText(seconds: secondsLeft(for: site, at: context.date)))
                                    .monospacedDigit()
                            }
                            Button("End Break") {
                                model.endDailyBreak(for: site.domain)
                            }
                            .accessibilityLabel("End Break for \(site.domain)")
                        }
                        .frame(height: NotchLayout.rowHeight)
                    }

                    HStack {
                        Spacer()
                        Button("Open Focusward", action: controller.openMainWindow)
                    }
                    .frame(height: NotchLayout.rowHeight)
                }
                .controlSize(.small)
                .padding(NotchLayout.padding)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                bottomLeadingRadius: controller.isExpanded ? 18 : 10,
                bottomTrailingRadius: controller.isExpanded ? 18 : 10
            )
            .fill(.black)
        )
        .environment(\.colorScheme, .dark)
    }

    private func secondsLeft(for site: DailyLimitSite?, at date: Date) -> Int {
        max(0, Int(ceil((site?.activeBreak?.end ?? date).timeIntervalSince(date))))
    }
}
