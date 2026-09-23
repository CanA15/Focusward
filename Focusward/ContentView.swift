import AppKit
import SwiftUI

struct ContentView: View {
    @State private var selectedFeature = FocuswardFeature.focusSession

    var body: some View {
        ZStack {
            switch selectedFeature {
            case .focusSession:
                FocusSessionView()
                    .transition(.opacity)
            case .dailyLimits:
                DailyLimitsView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Feature", selection: $selectedFeature.animation(.easeInOut(duration: 0.2))) {
                    ForEach(FocuswardFeature.allCases) { feature in
                        Text(feature.rawValue).tag(feature)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }
}

private enum FocuswardFeature: String, CaseIterable, Identifiable {
    case focusSession = "Focus Session"
    case dailyLimits = "Daily Limits"

    var id: Self { self }
}

// MARK: - Focus Session

private struct FocusSessionView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        Form {
            Section {
                FocusHero()
            }

            Section {
                ForEach(model.domains, id: \.self) { domain in
                    WebsiteRow(domain: domain, isLocked: model.isSessionActive) {
                        withAnimation(.snappy) { model.removeDomain(domain) }
                    }
                }

                if !model.isSessionActive {
                    AddWebsiteRow(
                        text: $model.draftDomain,
                        accessibilityLabel: "Website to block"
                    ) {
                        withAnimation(.snappy) { model.addDraftDomain() }
                    }
                }
            } header: {
                Text("Blocked Websites")
            } footer: {
                Text(
                    model.isSessionActive
                        ? "You can change the websites after the session ends."
                        : "Subdomains are blocked too. Blocking applies to Safari, and your settings stay on this Mac."
                )
            }

            if model.isSessionActive {
                Section("End Early") {
                    EarlyEndControls()
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct FocusHero: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        VStack(spacing: 20) {
            if model.isSessionActive {
                activeContent
            } else {
                setupContent
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .animation(.smooth(duration: 0.35), value: model.isSessionActive)
        .animation(.smooth(duration: 0.3), value: model.usesCustomDuration)
    }

    private var setupContent: some View {
        Group {
            StatusCapsule(text: model.automationMessage, isActive: false)

            VStack(spacing: 6) {
                Text(countdownText(seconds: model.selectedDurationMinutes * 60))
                    .font(.system(size: 64, weight: .light).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.selectedDurationMinutes)

                TimelineView(.everyMinute) { context in
                    Text(endText(for: context.date.addingTimeInterval(TimeInterval(model.selectedDurationMinutes * 60))))
                        .foregroundStyle(.secondary)
                }
            }

            DurationPicker()

            if model.usesCustomDuration {
                HStack(spacing: 20) {
                    NumberStepper(
                        title: "Hours",
                        unit: "h",
                        value: model.customHours,
                        range: 0 ... FocusDuration.maximumHours,
                        step: 1,
                        onChange: model.setCustomHours
                    )
                    NumberStepper(
                        title: "Minutes",
                        unit: "min",
                        value: model.customMinutes,
                        range: 0 ... 59,
                        step: 5,
                        isEnabled: model.customHours < FocusDuration.maximumHours,
                        onChange: model.setCustomMinutes
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(spacing: 8) {
                Button {
                    withAnimation(.smooth(duration: 0.35)) { model.startSession() }
                } label: {
                    Text("Start Session")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(!model.canStartSession)

                if model.domains.isEmpty {
                    Text("Add a website below to start a session.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var activeContent: some View {
        Group {
            StatusCapsule(text: "Session active", isActive: true)

            VStack(spacing: 6) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(countdownText(seconds: remainingSeconds(at: context.date)))
                        .font(.system(size: 64, weight: .light).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: remainingSeconds(at: context.date))
                }

                if let end = model.sessionEnd {
                    Text(endText(for: end))
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(model.automationMessage) · \(tabCountText(model.redirectedTabCount)) redirected")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func remainingSeconds(at date: Date) -> Int {
        max(0, Int((model.sessionEnd ?? date).timeIntervalSince(date)))
    }
}

private struct DurationPicker: View {
    @EnvironmentObject private var model: FocuswardModel
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FocusDuration.presets, id: \.self) { minutes in
                option(
                    FocusDuration.compactLabel(totalMinutes: minutes),
                    isSelected: !model.usesCustomDuration && model.durationMinutes == minutes
                ) {
                    model.selectDurationPreset(minutes)
                }
            }

            option("Custom", isSelected: model.usesCustomDuration) {
                model.selectCustomDuration()
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func option(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) { action() }
        } label: {
            Text(title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(minWidth: 52)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color(nsColor: .controlColor))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "selection", in: selection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct EarlyEndControls: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        if model.hasEarlyEndRequest {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                let display = model.earlyEndDisplay(at: context.date)

                if model.earlyEndIsReady(at: context.date) {
                    HStack {
                        Text("The cooldown is complete. Confirm to end the session.")
                        Spacer()
                        Button("Keep Session", action: model.cancelEarlyEnd)
                        Button("End Session", role: .destructive) {
                            withAnimation(.smooth(duration: 0.35)) { model.confirmEarlyEnd() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cooldown · about \(display.text) left")
                                    .monospacedDigit()
                                Text(
                                    model.isEarlyEndTimerRunning
                                        ? "The cooldown advances while this window is in front."
                                        : "Paused. Bring this window to the front to continue."
                                )
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Cancel", action: model.cancelEarlyEnd)
                        }

                        ProgressView(value: display.progress)
                            .progressViewStyle(.linear)
                            .labelsHidden()
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
                    Text("Ending early starts a cooldown. You can cancel it at any time.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Request Early End", action: model.requestEarlyEnd)
            }
        }
    }
}

// MARK: - Daily Limits

private struct DailyLimitsView: View {
    @EnvironmentObject private var model: FocuswardModel

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { model.dailyLimits.isActive },
            set: { active in
                withAnimation(.snappy) { model.setDailyLimitsActive(active) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: activeBinding) {
                    Text("Daily Limits")
                    Text("Time counts only while Safari is in front and the website is in the active tab.")
                }
                .toggleStyle(.switch)
                .disabled(!model.canActivateDailyLimits && !model.dailyLimits.isActive)

                LabeledContent("Status", value: model.dailyLimitsMessage)

                if model.dailyLimits.isActive {
                    LabeledContent("Redirected", value: tabCountText(model.dailyRedirectedTabCount))
                }
            } footer: {
                Text(protectionFooter)
            }

            Section {
                ForEach(model.dailyLimits.sites) { site in
                    DailyLimitRow(site: site)
                }

                if !model.dailyLimits.isActive {
                    AddWebsiteRow(
                        text: $model.dailyDraftDomain,
                        accessibilityLabel: "Website for a daily limit"
                    ) {
                        withAnimation(.snappy) { model.addDailyDraftSite() }
                    } accessory: {
                        NumberStepper(
                            title: "Minutes per day",
                            unit: "min",
                            value: model.dailyDraftAllowanceMinutes,
                            range: DailyLimits.allowanceRange,
                            step: 5,
                            onChange: model.setDailyDraftAllowanceMinutes
                        )
                    }
                }
            } header: {
                Text("Websites")
            } footer: {
                Text("Each rule also applies to its subdomains.")
            }
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                model.refreshDailyLimits()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var protectionFooter: String {
        if model.dailyLimits.isActive {
            return "Allowances reset at midnight. Turn off Daily Limits to change the websites."
        }
        if !model.canActivateDailyLimits {
            return "Add a website below to turn on Daily Limits."
        }
        return "Allowances reset at midnight."
    }
}

private struct DailyLimitRow: View {
    @EnvironmentObject private var model: FocuswardModel
    let site: DailyLimitSite

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.domain)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(statusText(at: context.date))
                            .font(.callout)
                            .foregroundStyle(site.isExhausted ? Color.red : Color.secondary)
                            .monospacedDigit()
                    }
                }

                Spacer()

                if model.dailyLimits.isActive {
                    Text("\(site.allowanceMinutes) min a day")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    NumberStepper(
                        title: "Minutes per day for \(site.domain)",
                        unit: "min",
                        value: site.allowanceMinutes,
                        range: DailyLimits.allowanceRange,
                        step: 5,
                        onChange: { model.updateDailyAllowance(for: site.domain, minutes: $0) }
                    )
                    RemoveButton(domain: site.domain) {
                        withAnimation(.snappy) { model.removeDailyLimit(for: site.domain) }
                    }
                }
            }

            ProgressView(value: min(max(site.usedSeconds / site.allowanceSeconds, 0), 1))
                .progressViewStyle(.linear)
                .labelsHidden()
                .tint(site.isExhausted ? Color.red : Color.accentColor)
                .animation(.smooth, value: site.usedSeconds)
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
            return "No time left today"
        }
        return "\(durationText(seconds: site.remainingSeconds)) left today"
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

// MARK: - Shared controls

private struct WebsiteRow: View {
    let domain: String
    let isLocked: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(domain)
                .textSelection(.enabled)
            Spacer()
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Locked")
            } else {
                RemoveButton(domain: domain, action: onRemove)
            }
        }
    }
}

private struct AddWebsiteRow<Accessory: View>: View {
    @Binding var text: String
    let accessibilityLabel: String
    let onAdd: () -> Void
    @ViewBuilder let accessory: Accessory
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TextField(accessibilityLabel, text: $text, prompt: Text("Add a website, such as youtube.com"))
                .textFieldStyle(.plain)
                .labelsHidden()
                .focused($isFocused)
                .onSubmit(onAdd)
                .onAppear { isFocused = true }
            accessory
            Button("Add", action: onAdd)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

extension AddWebsiteRow where Accessory == EmptyView {
    init(text: Binding<String>, accessibilityLabel: String, onAdd: @escaping () -> Void) {
        self.init(text: text, accessibilityLabel: accessibilityLabel, onAdd: onAdd) { EmptyView() }
    }
}

private struct RemoveButton: View {
    let domain: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(isHovered ? Color.secondary : Color.secondary.opacity(0.5))
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Remove \(domain)")
        .help("Remove \(domain)")
    }
}

private struct NumberStepper: View {
    let title: String
    let unit: String
    let value: Int
    let range: ClosedRange<Int>
    let step: Int
    var isEnabled = true
    let onChange: (Int) -> Void

    private var valueBinding: Binding<Int> {
        Binding(
            get: { value },
            set: { newValue in
                // A text field writes its value back when it gains focus. Ignore unchanged values.
                let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                guard clamped != value else { return }
                onChange(clamped)
            }
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField(title, value: valueBinding, format: .number)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 52)
            Text(unit)
                .foregroundStyle(.secondary)
            Stepper(title, value: valueBinding, in: range, step: step)
                .labelsHidden()
        }
        .disabled(!isEnabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct StatusCapsule: View {
    let text: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(isActive ? Color.green : Color.secondary.opacity(0.6))
                .symbolEffect(.pulse, isActive: isActive)
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05), in: Capsule())
        .contentTransition(.opacity)
    }
}

// MARK: - Menu bar

struct MenuBarContentView: View {
    @EnvironmentObject private var model: FocuswardModel
    let showMainWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Focusward", systemImage: model.isProtectionActive ? "shield.fill" : "shield")
                        .font(.headline)
                    Spacer()
                    Text(model.isProtectionActive ? "Active" : "Off")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(model.isProtectionActive ? Color.green : Color.secondary)
                }

                if model.isSessionActive {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(countdownText(seconds: max(0, Int((model.sessionEnd ?? context.date).timeIntervalSince(context.date)))))
                                .font(.system(size: 30, weight: .light).monospacedDigit())
                        }
                        Text(model.automationMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                if model.dailyLimits.isActive {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Daily Limits")
                            Spacer()
                            Text("\(model.dailyLimits.sites.count) website\(model.dailyLimits.sites.count == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                        if !model.isSessionActive || model.dailyLimitsMessage != model.automationMessage {
                            Text(model.dailyLimitsMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }

                if !model.isProtectionActive {
                    Text("No session or daily limit is active.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)

            Divider()
                .padding(.horizontal, 10)

            VStack(spacing: 0) {
                Button(action: showMainWindow) {
                    Label("Open Focusward", systemImage: "macwindow")
                }

                if model.isSessionActive {
                    if model.hasEarlyEndRequest {
                        Button(action: model.cancelEarlyEnd) {
                            Label("Cancel Early-End Request", systemImage: "xmark.circle")
                        }
                    } else {
                        Button(action: model.requestEarlyEnd) {
                            Label("Request Early End", systemImage: "hourglass")
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
            .padding(5)
        }
        .frame(width: 280)
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
                .labelStyle(MenuRowLabelStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
                .background(
                    isHovered ? Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
        }
    }
}

private struct MenuRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .frame(width: 18)
            configuration.title
        }
    }
}

// MARK: - Formatting

private func countdownText(seconds: Int) -> String {
    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = (seconds % 3_600) / 60
    let remainder = seconds % 60

    if days > 0 {
        return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, remainder)
    }
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
    return String(format: "%02d:%02d", minutes, remainder)
}

private func endText(for end: Date) -> String {
    Calendar.current.isDateInToday(end)
        ? "Ends at \(end.formatted(date: .omitted, time: .shortened))"
        : "Ends \(end.formatted(date: .abbreviated, time: .shortened))"
}

private func tabCountText(_ count: Int) -> String {
    "\(count) tab\(count == 1 ? "" : "s")"
}
