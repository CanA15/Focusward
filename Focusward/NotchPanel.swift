import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var notchSize: CGSize = .zero
    @Published private(set) var expandedSize: CGSize = .zero

    let showMainWindow: () -> Void
    private let model: FocuswardModel
    private var panel: NSPanel?
    private var isPointerInside = false
    private var breakCount = 0
    private var isEnabled = false
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

    private var animation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(duration: 0.4, bounce: 0.25)
    }

    fileprivate func setPointerInside(_ isInside: Bool) {
        guard isInside != isPointerInside else { return }
        isPointerInside = isInside

        if isInside {
            // The window grows first. The shape then grows from the notch inside the window.
            updatePanel()
            panel?.contentView?.layoutSubtreeIfNeeded()
            withAnimation(animation) { isExpanded = true }
        } else {
            // The window shrinks to the notch after the shape is back in the notch.
            withAnimation(animation) {
                isExpanded = false
            } completion: { [weak self] in
                self?.updatePanel()
            }
        }
    }

    private func updatePanel() {
        guard
            isEnabled,
            breakCount > 0,
            let notch = NSScreen.screens.lazy.compactMap(\.notchFrame).first
        else {
            isPointerInside = false
            isExpanded = false
            panel?.orderOut(nil)
            return
        }

        // One row for each break and one row for Open Focusward.
        let rowCount = breakCount + 1
        notchSize = notch.size
        expandedSize = NotchLayout.panelFrame(notch: notch, isExpanded: true, rowCount: rowCount).size
        let panel = panel ?? makePanel()
        panel.setFrame(
            NotchLayout.panelFrame(
                notch: notch,
                isExpanded: isPointerInside || isExpanded,
                rowCount: rowCount
            ),
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

        let hostingView = NotchHostingView(
            rootView: NotchView(controller: self).environmentObject(model)
        )
        hostingView.onPointerInsideChange = { [weak self] isInside in
            self?.setPointerInside(isInside)
        }
        panel.contentView = hostingView
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

private final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var onPointerInsideChange: ((Bool) -> Void)?
    private var pointerTrackingArea: NSTrackingArea?

    // The panel never becomes active, so the first click must operate a control.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // Focusward is usually in the background, so the tracking area must always be active.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard pointerTrackingArea == nil else { return }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        pointerTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onPointerInsideChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointerInsideChange?(false)
    }
}

private struct NotchView: View {
    @EnvironmentObject private var model: FocuswardModel
    @ObservedObject var controller: NotchPanelController

    var body: some View {
        let shapeSize = controller.isExpanded ? controller.expandedSize : controller.notchSize
        let cornerRadius: CGFloat = controller.isExpanded ? 20 : 8

        ZStack(alignment: .top) {
            Color.black

            if controller.isExpanded {
                breakList
                    .padding(.horizontal, NotchLayout.padding)
                    .padding(.top, controller.notchSize.height)
                    .padding(.bottom, NotchLayout.padding)
                    .frame(width: controller.expandedSize.width)
                    .transition(.opacity)
            }
        }
        .frame(width: shapeSize.width, height: shapeSize.height, alignment: .top)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private var breakList: some View {
        VStack(spacing: 0) {
            ForEach(model.dailyLimits.sitesOnBreak) { site in
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
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
                Button("Open Focusward", action: controller.showMainWindow)
            }
            .frame(height: NotchLayout.rowHeight)
        }
        .controlSize(.small)
    }

    private func secondsLeft(for site: DailyLimitSite, at date: Date) -> Int {
        max(0, Int(ceil((site.activeBreak?.end ?? date).timeIntervalSince(date))))
    }
}
