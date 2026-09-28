import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var notchSize: CGSize = .zero
    @Published private(set) var expandedSize: CGSize = .zero
    // While the shape is outside the notch or on its way back into it, the shape is black and the
    // window has the expanded size. At other times the panel is transparent and covers only the notch.
    @Published private(set) var isShapeFilled = false

    let showMainWindow: () -> Void
    private let model: FocuswardModel
    private var panel: NSPanel?
    private var hostingView: NotchHostingView?
    private var openTask: Task<Void, Never>?
    private var breakCount = 0
    private var isEnabled = false
    private var cancellables: Set<AnyCancellable> = []

    init(model: FocuswardModel, showMainWindow: @escaping () -> Void) {
        self.model = model
        self.showMainWindow = showMainWindow

        // @Published emits before the model stores the new value, so pass the values on.
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

    private func setPointerInside(_ isInside: Bool) {
        openTask?.cancel()
        openTask = nil

        guard isInside else {
            close()
            return
        }
        // The pointer is back while the shape collapses, so the shape grows again at once.
        if isShapeFilled {
            open()
            return
        }
        // A short delay stops the panel from opening when the pointer only crosses the notch.
        openTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.open()
        }
    }

    private func open() {
        guard !isExpanded else { return }
        isShapeFilled = true

        // The window grows first. The shape then grows from the notch inside the window.
        updatePanel()
        hostingView?.layoutSubtreeIfNeeded()
        withAnimation(animation) { isExpanded = true }
    }

    private func close() {
        guard isExpanded else { return }

        // The window shrinks to the notch after the shape is back in the notch.
        withAnimation(animation) {
            isExpanded = false
        } completion: { [weak self] in
            guard let self, !self.isExpanded else { return }
            self.isShapeFilled = false
            self.updatePanel()
        }
    }

    private func updatePanel() {
        guard
            isEnabled,
            breakCount > 0,
            let notch = NSScreen.screens.lazy.compactMap(\.notchFrame).first
        else {
            hidePanel()
            return
        }

        notchSize = notch.size
        let panel = panel ?? makePanel()
        let expandedFrame = NotchLayout.expandedFrame(notch: notch, breakCount: breakCount)
        let frame = isShapeFilled ? expandedFrame : notch
        let newExpandedSize = expandedFrame.size

        // A break starts or ends while the panel is open. A larger shape needs the larger window
        // before it grows. A smaller shape shrinks before the window does.
        if isExpanded, newExpandedSize != expandedSize {
            if newExpandedSize.height > expandedSize.height {
                panel.setFrame(frame, display: true)
            }
            withAnimation(animation) {
                expandedSize = newExpandedSize
            } completion: { [weak self] in
                self?.updatePanel()
            }
            return
        }

        expandedSize = newExpandedSize
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func hidePanel() {
        openTask?.cancel()
        openTask = nil
        isExpanded = false
        isShapeFilled = false
        panel?.orderOut(nil)
        // A hidden panel receives no exit event. A new tracking area starts with the pointer outside.
        hostingView?.resetPointerTracking()
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
            rootView: NotchView(controller: self, model: model)
        )
        hostingView.onPointerInsideChange = { [weak self] isInside in
            self?.setPointerInside(isInside)
        }
        panel.contentView = hostingView
        self.panel = panel
        self.hostingView = hostingView
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

private final class NotchHostingView: NSHostingView<NotchView> {
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

    func resetPointerTracking() {
        if let pointerTrackingArea {
            removeTrackingArea(pointerTrackingArea)
            self.pointerTrackingArea = nil
        }
        updateTrackingAreas()
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
    @ObservedObject var controller: NotchPanelController
    // Only the break list observes the model, so model changes do not redraw a collapsed panel.
    let model: FocuswardModel

    var body: some View {
        let isExpanded = controller.isExpanded
        let size = isExpanded ? controller.expandedSize : controller.notchSize
        let shape = NotchShape(
            shoulderRadius: isExpanded ? NotchLayout.shoulderRadius : 0,
            cornerRadius: isExpanded ? 24 : 8
        )

        ZStack(alignment: .top) {
            background(height: size.height)
                .opacity(isExpanded ? 1 : 0)

            if isExpanded {
                NotchBreakList(model: model, showMainWindow: controller.showMainWindow)
                    .padding(.top, controller.notchSize.height)
                    .frame(width: controller.expandedSize.width)
                    .transition(.blurReplace)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        // The collapsed shape stays transparent. Screenshots, screen sharing, and mirrored displays
        // show the notch area, so a black shape there would be visible to other people.
        .background(Color.black.opacity(controller.isShapeFilled ? 1 : 0))
        .clipShape(shape)
        .overlay {
            shape
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .opacity(isExpanded ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    // The band beside the camera stays pure black, so the shape joins the notch without a seam.
    private func background(height: CGFloat) -> some View {
        let bandEnd = min(controller.notchSize.height / max(height, 1), 1)

        return LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: bandEnd),
                .init(color: Color(red: 0.08, green: 0.08, blue: 0.095), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .bottom) {
            RadialGradient(
                colors: [Color.accentColor.opacity(0.28), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 240
            )
        }
    }
}

private struct NotchBreakList: View {
    @ObservedObject var model: FocuswardModel
    let showMainWindow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.dailyLimits.sitesOnBreak) { site in
                if let activeBreak = site.activeBreak {
                    NotchBreakRow(domain: site.domain, activeBreak: activeBreak) {
                        model.endDailyBreak(for: site.domain)
                    }
                    .frame(height: NotchLayout.rowHeight)
                }
            }

            HStack {
                Text("Daily Limits")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button(action: showMainWindow) {
                    Label("Open Focusward", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(NotchLinkButtonStyle())
            }
            .frame(height: NotchLayout.footerHeight)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, NotchLayout.horizontalInset)
        .padding(.bottom, NotchLayout.bottomInset)
        .foregroundStyle(.white)
    }
}

private struct NotchBreakRow: View {
    let domain: String
    let activeBreak: DailyBreak
    let onEndBreak: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let secondsLeft = activeBreak.secondsLeft(at: context.date)
            let fractionLeft = activeBreak.fractionLeft(at: context.date)
            let isInLastMinute = activeBreak.isInLastMinute(at: context.date)
            let tint = isInLastMinute ? Color.orange : Color.accentColor

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: fractionLeft)
                        .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: fractionLeft)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(domain)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("On a break")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 8)

                Text(countdownText(seconds: secondsLeft))
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isInLastMinute ? Color.orange : Color.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: secondsLeft)

                Button("End Break", action: onEndBreak)
                    .buttonStyle(NotchCapsuleButtonStyle())
                    .accessibilityLabel("End Break for \(domain)")
            }
        }
    }
}

private struct NotchShape: Shape {
    var shoulderRadius: CGFloat
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderRadius, cornerRadius) }
        set {
            shoulderRadius = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let shoulder = max(0, min(shoulderRadius, rect.width / 4, rect.height / 2))
        let corner = max(0, min(cornerRadius, (rect.width - 2 * shoulder) / 2, rect.height - shoulder))
        let left = rect.minX + shoulder
        let right = rect.maxX - shoulder

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: left, y: rect.minY),
            tangent2End: CGPoint(x: left, y: rect.maxY),
            radius: shoulder
        )
        path.addArc(
            tangent1End: CGPoint(x: left, y: rect.maxY),
            tangent2End: CGPoint(x: right, y: rect.maxY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: right, y: rect.maxY),
            tangent2End: CGPoint(x: right, y: rect.minY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: right, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: shoulder
        )
        path.closeSubpath()
        return path
    }
}

private struct NotchCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(configuration.isPressed ? 0.28 : 0.14), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

private struct NotchLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.95 : 0.65))
            .contentShape(Rectangle())
    }
}
