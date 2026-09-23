import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: FocuswardModel
    @State private var selectedFeature = FocuswardFeature.focusSession

    var body: some View {
        Group {
            switch selectedFeature {
            case .focusSession:
                if model.isSessionActive {
                    ActiveSessionView()
                } else {
                    SetupView()
                }
            case .dailyLimits:
                DailyLimitsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pageBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Feature", selection: $selectedFeature) {
                    ForEach(FocuswardFeature.allCases) { feature in
                        Text(feature.rawValue).tag(feature)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
        }
        .tint(.focusAccent)
    }
}

private enum FocuswardFeature: String, CaseIterable, Identifiable {
    case focusSession = "Focus Session"
    case dailyLimits = "Daily Limits"

    var id: Self { self }
}

private extension Color {
    static let focusAccent = Color.indigo

    // The page and card colors follow the grouped palette of the Safari shield page.
    static let pageBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.11, alpha: 1)
            : NSColor(white: 0.96, alpha: 1)
    })

    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.17, alpha: 1)
            : NSColor.white
    })
}

private struct FeaturePage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct IconBadge: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct WebsiteMonogram: View {
    let domain: String

    var body: some View {
        Text(domain.prefix(1).uppercased())
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.focusAccent)
            .frame(width: 32, height: 32)
            .background(Color.focusAccent.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct WebsiteEntryField: View {
    let accessibilityLabel: String
    @Binding var text: String
    let onAdd: () -> Void
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                TextField("Website, such as youtube.com", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .accessibilityLabel(accessibilityLabel)
                    .onSubmit(onAdd)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.focusAccent : Color.primary.opacity(0.1),
                        lineWidth: isFocused ? 2 : 1
                    )
            }
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .opacity(isEnabled ? 1 : 0.5)

            Button("Add", action: onAdd)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

private struct EmptyWebsiteList: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
                .background(Color.primary.opacity(0.05), in: Circle())
            Text(title)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

private struct SetupView: View {
    @EnvironmentObject private var model: FocuswardModel

    private let durationColumns = Array(
        repeating: GridItem(.flexible(minimum: 68), spacing: 8),
        count: 6
    )

    var body: some View {
        FeaturePage(
            title: "Time to focus.",
            subtitle: "Choose which websites to block and how long to focus."
        ) {
            SettingsSection(
                title: "Blocked websites",
                footer: "Each website rule also blocks its subdomains."
            ) {
                WebsiteEntryField(
                    accessibilityLabel: "Website to block",
                    text: $model.draftDomain,
                    onAdd: model.addDraftDomain
                )

                if model.domains.isEmpty {
                    EmptyWebsiteList(
                        title: "No websites added",
                        subtitle: "Add a website to set up your session."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.domains, id: \.self) { domain in
                            HStack(spacing: 12) {
                                WebsiteMonogram(domain: domain)
                                Text(domain)
                                    .textSelection(.enabled)
                                Spacer()
                                Button {
                                    model.removeDomain(domain)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(domain)")
                                .help("Remove \(domain)")
                            }
                            .padding(.vertical, 8)
                            if domain != model.domains.last {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
            }

            SettingsSection(title: "Session length") {
                LazyVGrid(columns: durationColumns, spacing: 8) {
                    ForEach(FocusDuration.presets, id: \.self) { minutes in
                        DurationChoiceButton(
                            title: FocusDuration.compactLabel(totalMinutes: minutes),
                            subtitle: quickDurationSubtitle(minutes),
                            isSelected: !model.usesCustomDuration && model.durationMinutes == minutes
                        ) {
                            model.selectDurationPreset(minutes)
                        }
                    }

                    DurationChoiceButton(
                        title: "Custom",
                        subtitle: "Up to 30 days",
                        isSelected: model.usesCustomDuration,
                        action: model.selectCustomDuration
                    )
                }

                if model.usesCustomDuration {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            customHoursControl
                            customMinutesControl
                        }
                        VStack(spacing: 10) {
                            customHoursControl
                            customMinutesControl
                        }
                    }
                }
            }

            Label("Your settings stay on this Mac. Blocking applies to Safari.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.selectedDurationMinutes > 0 ? model.durationSummary : "Choose a duration")
                            .font(.system(.headline, design: .rounded))
                        Text(model.automationMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button(action: model.startSession) {
                        Label("Start Session", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .disabled(!model.canStartSession)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }
            .background(.bar)
        }
    }

    private func quickDurationSubtitle(_ minutes: Int) -> String {
        switch minutes {
        case 25: "Short"
        case 45: "Standard"
        case 60: "One hour"
        case 120: "Two hours"
        case 240: "Four hours"
        default: "Preset"
        }
    }

    private var customHoursControl: some View {
        DurationStepper(
            title: "Hours",
            value: model.customHours,
            range: 0...FocusDuration.maximumHours,
            step: 1,
            onChange: model.setCustomHours
        )
    }

    private var customMinutesControl: some View {
        DurationStepper(
            title: "Minutes",
            value: model.customMinutes,
            range: 0...59,
            step: 5,
            isEnabled: model.customHours < FocusDuration.maximumHours,
            onChange: model.setCustomMinutes
        )
    }
}

private struct DailyLimitsView: View {
    @EnvironmentObject private var model: FocuswardModel

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { model.dailyLimits.isActive },
            set: { model.setDailyLimitsActive($0) }
        )
    }

    var body: some View {
        FeaturePage(
            title: "Set your daily limits.",
            subtitle: "Give each website a daily allowance. Allowances reset at local midnight."
        ) {
            SettingsSection(title: "Daily protection", footer: protectionFooter) {
                HStack(spacing: 14) {
                    IconBadge(
                        systemImage: "shield.lefthalf.filled",
                        color: model.dailyLimits.isActive ? .green : .gray,
                        size: 40
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.dailyLimits.isActive ? "Daily Limits are active" : "Daily Limits are inactive")
                            .font(.system(.headline, design: .rounded))
                        Text("Counts use while Safari and the website are active.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Toggle("Daily Limits", isOn: activeBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!model.canActivateDailyLimits && !model.dailyLimits.isActive)
                }

                Divider()

                StatusRow(
                    title: "Safari",
                    value: model.dailyLimitsMessage,
                    systemImage: "safari",
                    color: .blue
                )

                if model.dailyLimits.isActive {
                    StatusRow(
                        title: "Redirected",
                        value: "\(model.dailyRedirectedTabCount) tab\(model.dailyRedirectedTabCount == 1 ? "" : "s")",
                        systemImage: "arrow.turn.down.right",
                        color: .orange
                    )
                }
            }

            SettingsSection(
                title: "Add a website",
                footer: "Each website rule also applies to its subdomains."
            ) {
                WebsiteEntryField(
                    accessibilityLabel: "Website for a daily limit",
                    text: $model.dailyDraftDomain,
                    onAdd: { model.addDailyDraftSite() }
                )

                DurationStepper(
                    title: "Minutes per day",
                    value: model.dailyDraftAllowanceMinutes,
                    range: DailyLimits.allowanceRange,
                    step: 5,
                    onChange: { model.setDailyDraftAllowanceMinutes($0) }
                )
            }
            .disabled(model.dailyLimits.isActive)

            SettingsSection(title: "Website limits") {
                if model.dailyLimits.sites.isEmpty {
                    EmptyWebsiteList(
                        title: "No daily limits added",
                        subtitle: "Add a website and choose its daily allowance."
                    )
                } else {
                    ForEach(model.dailyLimits.sites) { site in
                        DailyLimitSiteRow(site: site)
                        if site.id != model.dailyLimits.sites.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                model.refreshDailyLimits()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var protectionFooter: String? {
        if model.dailyLimits.isActive {
            return "Deactivate Daily Limits to change the settings."
        }
        if !model.canActivateDailyLimits {
            return "Add a website below to activate Daily Limits."
        }
        return nil
    }
}

private struct DailyLimitSiteRow: View {
    @EnvironmentObject private var model: FocuswardModel
    let site: DailyLimitSite

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                WebsiteMonogram(domain: site.domain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(site.domain)
                        .fontWeight(.medium)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(statusText(at: context.date))
                            .font(.callout)
                            .foregroundStyle(site.isExhausted ? Color.red : Color.secondary)
                            .monospacedDigit()
                    }
                }

                Spacer()

                Button {
                    model.removeDailyLimit(for: site.domain)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(model.dailyLimits.isActive)
                .accessibilityLabel("Remove \(site.domain)")
                .help("Remove \(site.domain)")
            }

            ProgressView(value: min(max(site.usedSeconds / site.allowanceSeconds, 0), 1))
                .progressViewStyle(.linear)
                .labelsHidden()
                .tint(site.isExhausted ? Color.red : Color.focusAccent)

            DurationStepper(
                title: "Minutes per day",
                value: site.allowanceMinutes,
                range: DailyLimits.allowanceRange,
                step: 5,
                isEnabled: !model.dailyLimits.isActive,
                onChange: { model.updateDailyAllowance(for: site.domain, minutes: $0) }
            )
            .disabled(model.dailyLimits.isActive)
        }
        .padding(.vertical, 4)
    }

    private func statusText(at date: Date) -> String {
        if
            model.dailyLimits.isActive,
            site.isExhausted,
            let blockedSince = site.blockedSince
        {
            return "Blocked for \(durationText(seconds: date.timeIntervalSince(blockedSince)))"
        }
        if site.isExhausted {
            return "No time remains today"
        }
        return "\(durationText(seconds: site.remainingSeconds)) left"
    }

    private func durationText(seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainingSeconds = total % 60

        if hours > 0 {
            let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
            return minutes > 0 ? "\(hourText) \(minutes) min" : hourText
        }
        if minutes > 0 {
            return "\(minutes) min"
        }
        return remainingSeconds == 1 ? "1 second" : "\(remainingSeconds) seconds"
    }
}

private struct DurationChoiceButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            isSelected ? Color.focusAccent : Color.primary.opacity(isHovered ? 0.08 : 0.04),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DurationStepper: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let step: Int
    var isEnabled = true
    let onChange: (Int) -> Void

    private var valueBinding: Binding<Int> {
        Binding(
            get: { value },
            set: { onChange(min(max($0, range.lowerBound), range.upperBound)) }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout.weight(.medium))

            Spacer()

            TextField("", value: valueBinding, format: .number)
                .textFieldStyle(.plain)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .accessibilityLabel(title)

            VStack(spacing: 0) {
                RepeatingStepButton(
                    systemImage: "plus",
                    accessibilityLabel: "Increase \(title)",
                    isEnabled: isEnabled && value < range.upperBound
                ) {
                    onChange(min(range.upperBound, value + step))
                }
                .frame(width: 24, height: 18)

                RepeatingStepButton(
                    systemImage: "minus",
                    accessibilityLabel: "Decrease \(title)",
                    isEnabled: isEnabled && value > range.lowerBound
                ) {
                    onChange(max(range.lowerBound, value - step))
                }
                .frame(width: 24, height: 18)
            }
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 190, maxWidth: .infinity, minHeight: 46)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .disabled(!isEnabled)
    }
}

private struct RepeatingStepButton: NSViewRepresentable {
    let systemImage: String
    let accessibilityLabel: String
    let isEnabled: Bool
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.isContinuous = true
        button.setPeriodicDelay(0.35, interval: 0.08)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.image = NSImage(
            systemSymbolName: systemImage,
            accessibilityDescription: accessibilityLabel
        )
        button.isEnabled = isEnabled
        button.toolTip = accessibilityLabel
        button.setAccessibilityLabel(accessibilityLabel)
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

private struct ActiveSessionView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        FeaturePage(
            title: "Your focus session.",
            subtitle: "Your website rules apply until the session ends."
        ) {
            SessionSummary()

            SettingsSection(title: "Session status") {
                StatusRow(
                    title: "Safari",
                    value: model.automationMessage,
                    systemImage: "safari",
                    color: .blue
                )
                Divider()
                StatusRow(
                    title: "Redirected",
                    value: "\(model.redirectedTabCount) tab\(model.redirectedTabCount == 1 ? "" : "s")",
                    systemImage: "arrow.turn.down.right",
                    color: .orange
                )
            }

            SettingsSection(title: "End the session early") {
                EarlyEndControls()
            }
        }
    }
}

private struct SessionSummary: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("Session active")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: Capsule())

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(remainingText(at: context.date))
                    .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            if let end = model.sessionEnd {
                Text("Ends \(end.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .background(
            LinearGradient(
                colors: [Color.focusAccent.opacity(0.18), Color.focusAccent.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.focusAccent.opacity(0.2), lineWidth: 1)
        }
    }

    private func remainingText(at date: Date) -> String {
        let seconds = max(0, Int((model.sessionEnd ?? date).timeIntervalSince(date)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60

        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, remainder)
        }
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: systemImage, color: color)
            Text(title)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EarlyEndControls: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        if model.hasEarlyEndRequest {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                let display = model.earlyEndDisplay(at: context.date)

                if model.earlyEndIsReady(at: context.date) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The cooldown is complete. Ending still requires confirmation.")
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Keep Session", action: model.cancelEarlyEnd)
                                .controlSize(.large)
                            Spacer()
                            Button("End Session", role: .destructive, action: model.confirmEarlyEnd)
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.large)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "hourglass", color: .focusAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Early-end cooldown")
                                    .fontWeight(.medium)
                                Text("Estimated wait · \(display.text)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                if !model.isEarlyEndTimerRunning {
                                    Text("Paused until this window is focused")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Cancel Request", action: model.cancelEarlyEnd)
                        }

                        ProgressView(value: display.progress)
                            .progressViewStyle(.linear)
                            .labelsHidden()
                            .tint(.focusAccent)
                            .animation(.easeInOut(duration: 0.5), value: display.progress)
                            .accessibilityLabel("Early-end request in progress")
                            .accessibilityValue("Waiting")
                    }
                }
            }
        } else {
            HStack(spacing: 12) {
                IconBadge(systemImage: "hourglass", color: .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Need to stop?")
                        .fontWeight(.medium)
                    Text("Early ending includes a focus cooldown and can be canceled.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Request Early End", action: model.requestEarlyEnd)
            }
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var model: FocuswardModel
    let showMainWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(
                        systemImage: model.isProtectionActive ? "shield.fill" : "shield",
                        color: model.isProtectionActive ? .focusAccent : .gray,
                        size: 34
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focusward")
                            .font(.headline)
                        Text(statusTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.isSessionActive {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(remainingText(at: context.date))
                            .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                    }

                    Text(model.automationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if model.dailyLimits.isActive {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(model.dailyLimits.sites.count) website\(model.dailyLimits.sites.count == 1 ? "" : "s") limited")
                            .font(.callout.weight(.medium))
                        Text(model.dailyLimitsMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .padding(14)

            Divider()
                .padding(.horizontal, 10)

            VStack(spacing: 2) {
                Button(action: showMainWindow) {
                    Label("Open Focusward", systemImage: "macwindow")
                }

                if model.isSessionActive {
                    if !model.hasEarlyEndRequest {
                        Button(action: model.requestEarlyEnd) {
                            Label("Request Early End", systemImage: "hourglass")
                        }
                    } else {
                        Button(action: model.cancelEarlyEnd) {
                            Label("Cancel Early-End Request", systemImage: "xmark.circle")
                        }
                    }
                }

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit Focusward", systemImage: "power")
                }
            }
            .buttonStyle(MenuRowButtonStyle())
            .padding(6)
        }
        .frame(width: 290)
        .tint(.focusAccent)
    }

    private var statusTitle: String {
        if model.isSessionActive {
            return "Focusward is active"
        }
        if model.dailyLimits.isActive {
            return "Daily Limits are active"
        }
        return "Focusward is ready"
    }

    private func remainingText(at date: Date) -> String {
        let seconds = max(0, Int((model.sessionEnd ?? date).timeIntervalSince(date)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m remaining"
        }
        return hours > 0
            ? "\(hours)h \(minutes)m remaining"
            : "\(minutes)m \(seconds % 60)s remaining"
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRow(configuration: configuration)
    }

    private struct MenuRow: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Color.primary.opacity(isHovered ? (configuration.isPressed ? 0.14 : 0.08) : 0),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
        }
    }
}
