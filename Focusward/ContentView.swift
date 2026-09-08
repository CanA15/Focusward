import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: FocuswardModel
    @State private var selectedFeature = FocuswardFeature.focusSession

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                AppIdentityRow()

                Spacer(minLength: 16)

                Picker("Feature", selection: $selectedFeature) {
                    ForEach(FocuswardFeature.allCases) { feature in
                        Text(feature.rawValue).tag(feature)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

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
        }
        .tint(.blue)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private enum FocuswardFeature: String, CaseIterable, Identifiable {
    case focusSession = "Focus Session"
    case dailyLimits = "Daily Limits"

    var id: Self { self }
}

private struct FeatureHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct EmptyWebsiteList: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 42, height: 42)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SetupView: View {
    @EnvironmentObject private var model: FocuswardModel

    private let durationColumns = Array(
        repeating: GridItem(.flexible(minimum: 68), spacing: 8),
        count: 6
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FeatureHeading(
                    title: "Time to focus.",
                    subtitle: "Choose which websites to block and how long to focus."
                )

                SettingsCard(title: "Blocked websites", systemImage: "globe") {
                    HStack(spacing: 10) {
                        TextField("Website, such as youtube.com", text: $model.draftDomain)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                            .accessibilityLabel("Website to block")
                            .onSubmit(model.addDraftDomain)

                        Button("Add", action: model.addDraftDomain)
                            .controlSize(.large)
                    }

                    if model.domains.isEmpty {
                        EmptyWebsiteList(
                            title: "No websites added",
                            subtitle: "Add a website to set up your session."
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.domains, id: \.self) { domain in
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .foregroundStyle(.secondary)
                                    Text(domain)
                                        .textSelection(.enabled)
                                    Spacer()
                                    Button(role: .destructive) {
                                        model.removeDomain(domain)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remove \(domain)")
                                    .help("Remove \(domain)")
                                }
                                .padding(.vertical, 9)
                                if domain != model.domains.last {
                                    Divider()
                                }
                            }
                        }
                    }

                    Text("Each website rule also blocks its subdomains.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsCard(title: "Session length", systemImage: "clock") {
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

                Label("Your settings stay on this Mac. Blocking applies to Safari.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(28)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.selectedDurationMinutes > 0 ? model.durationSummary : "Choose a duration")
                            .font(.headline)
                        Text(model.automationMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button(action: model.startSession) {
                        HStack(spacing: 12) {
                            Text("Start Session")
                            Image(systemName: "arrow.right")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!model.canStartSession)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }
            .background(Color(nsColor: .controlBackgroundColor))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FeatureHeading(
                    title: "Set your daily limits.",
                    subtitle: "Give each website a daily allowance. Allowances reset at local midnight."
                )

                SettingsCard(title: "Daily protection", systemImage: "shield.lefthalf.filled") {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.dailyLimits.isActive ? "Daily Limits are active" : "Daily Limits are inactive")
                                .fontWeight(.medium)
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

                    StatusRow(title: "Safari", value: model.dailyLimitsMessage, systemImage: "safari")

                    if model.dailyLimits.isActive {
                        Label("Deactivate Daily Limits to change the settings.", systemImage: "lock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !model.canActivateDailyLimits {
                        Text("Add a website below to activate Daily Limits.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsCard(title: "Add a website", systemImage: "plus.circle") {
                    HStack(spacing: 10) {
                        TextField("Website, such as youtube.com", text: $model.dailyDraftDomain)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                            .accessibilityLabel("Website for a daily limit")
                            .onSubmit { model.addDailyDraftSite() }

                        Button("Add") {
                            model.addDailyDraftSite()
                        }
                        .controlSize(.large)
                    }

                    DurationStepper(
                        title: "Minutes per day",
                        value: model.dailyDraftAllowanceMinutes,
                        range: DailyLimits.allowanceRange,
                        step: 5,
                        onChange: { model.setDailyDraftAllowanceMinutes($0) }
                    )

                    Text("Each website rule also applies to its subdomains.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(model.dailyLimits.isActive)

                SettingsCard(title: "Website limits", systemImage: "clock") {
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

                if model.dailyLimits.isActive {
                    StatusRow(
                        title: "Redirected",
                        value: "\(model.dailyRedirectedTabCount) tab\(model.dailyRedirectedTabCount == 1 ? "" : "s")",
                        systemImage: "arrow.turn.down.right"
                    )
                    .font(.callout)
                    .padding(.horizontal, 4)
                }
            }
            .padding(28)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .task {
            while !Task.isCancelled {
                model.refreshDailyLimits()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

private struct DailyLimitSiteRow: View {
    @EnvironmentObject private var model: FocuswardModel
    let site: DailyLimitSite

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Label(site.domain, systemImage: "globe")
                    .fontWeight(.medium)

                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(statusText(at: context.date))
                        .foregroundStyle(site.isExhausted ? Color.red : Color.secondary)
                        .monospacedDigit()
                }
            }

            ProgressView(value: min(max(site.usedSeconds / site.allowanceSeconds, 0), 1))
                .progressViewStyle(.linear)
                .labelsHidden()
                .tint(site.isExhausted ? .red : .blue)

            HStack {
                DurationStepper(
                    title: "Minutes per day",
                    value: site.allowanceMinutes,
                    range: DailyLimits.allowanceRange,
                    step: 5,
                    isEnabled: !model.dailyLimits.isActive,
                    onChange: { model.updateDailyAllowance(for: site.domain, minutes: $0) }
                )
                .disabled(model.dailyLimits.isActive)

                Spacer()

                Button(role: .destructive) {
                    model.removeDailyLimit(for: site.domain)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(model.dailyLimits.isActive)
                .accessibilityLabel("Remove \(site.domain)")
                .help("Remove \(site.domain)")
            }
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

private struct AppIdentityRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 38, height: 38)
                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text("Focusward")
                    .font(.headline)
                Text("Safari website blocker")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DurationChoiceButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? Color.blue : Color.primary)
        .background(
            isSelected ? Color.blue.opacity(0.07) : Color.primary.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? Color.blue : Color.primary.opacity(0.08),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
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
                .font(.headline.monospacedDigit())
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
            Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FeatureHeading(
                    title: "Your focus session.",
                    subtitle: "Your website rules apply until the session ends."
                )

                SessionSummary()

                SettingsCard(title: "Session status", systemImage: "safari") {
                    StatusRow(
                        title: "Safari",
                        value: model.automationMessage,
                        systemImage: "safari"
                    )
                    Divider()
                    StatusRow(
                        title: "Redirected",
                        value: "\(model.redirectedTabCount) tab\(model.redirectedTabCount == 1 ? "" : "s")",
                        systemImage: "arrow.turn.down.right"
                    )
                }

                SettingsCard(title: "End the session early", systemImage: "hourglass") {
                    EarlyEndControls()
                }
            }
            .padding(28)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SessionSummary: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 58, height: 58)
                .background(.blue.opacity(0.08), in: Circle())

            Text("Session active")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(remainingText(at: context.date))
                    .font(.system(size: 56, weight: .light, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }

            if let end = model.sessionEnd {
                Text("Ends \(end.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.blue.opacity(0.15), lineWidth: 1)
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Label(title, systemImage: systemImage)
            Spacer(minLength: 0)
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
                            Spacer()
                            Button("End Session", role: .destructive, action: model.confirmEarlyEnd)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Early-end cooldown")
                                    .fontWeight(.medium)
                                Text("Estimated wait · \(display.text)")
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
                            .tint(.blue)
                            .animation(.easeInOut(duration: 0.5), value: display.progress)
                            .accessibilityLabel("Early-end request in progress")
                            .accessibilityValue("Waiting")
                    }
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Need to stop?")
                        .fontWeight(.medium)
                    Text("Early ending includes a focus cooldown and can be canceled.")
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
        VStack(alignment: .leading, spacing: 12) {
            if model.isSessionActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focusward is active")
                            .font(.headline)
                        Text(remainingText(at: context.date))
                            .font(.title2.monospacedDigit())
                    }
                }
            } else if model.dailyLimits.isActive {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Limits are active")
                        .font(.headline)
                    Text("\(model.dailyLimits.sites.count) website\(model.dailyLimits.sites.count == 1 ? "" : "s") limited")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Focusward is ready")
                    .font(.headline)
            }

            if model.isSessionActive {
                Text(model.automationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if model.dailyLimits.isActive {
                Text(model.dailyLimitsMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Divider()

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
        .padding(14)
        .frame(width: 280)
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
