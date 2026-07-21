import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        Group {
            if model.isSessionActive {
                ActiveSessionView()
            } else {
                SetupView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
        }
    }
}

private struct SetupView: View {
    @EnvironmentObject private var model: FocuswardModel

    private let durationColumns = Array(
        repeating: GridItem(.flexible(minimum: 68), spacing: 8),
        count: 6
    )

    var body: some View {
        Form {
            Section {
                AppIdentityRow()
            }

            Section {
                HStack(spacing: 10) {
                    TextField("youtube.com", text: $model.draftDomain)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(model.addDraftDomain)

                    Button("Add", action: model.addDraftDomain)
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                }

                if model.domains.isEmpty {
                    Label("No blocked websites", systemImage: "globe")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.domains, id: \.self) { domain in
                        HStack {
                            Label(domain, systemImage: "globe")
                            Spacer()
                            Button(role: .destructive) {
                                model.removeDomain(domain)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove \(domain)")
                        }
                    }
                }
            } header: {
                Text("Blocked Websites")
            } footer: {
                Text("Each rule also blocks every subdomain.")
            }

            Section {
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
                        subtitle: "up to 30d",
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
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                LabeledContent {
                    Text(model.selectedDurationMinutes > 0 ? model.durationSummary : "Choose a duration")
                        .fontWeight(.medium)
                        .foregroundStyle(model.selectedDurationMinutes > 0 ? Color.primary : Color.red)
                } label: {
                    Label("Selected", systemImage: "clock")
                }
            } header: {
                Text("Session Length")
            }

            Section {
                LabeledContent {
                    Text(model.automationMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                } label: {
                    Label("Status", systemImage: "safari")
                }

                Button(action: model.startSession) {
                    Label("Start Session", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .disabled(!model.canStartSession)
            } footer: {
                Text("Everything stays on this Mac. Focusward asks to control Safari, never for an administrator password.")
            }
        }
        .formStyle(.grouped)
    }

    private func quickDurationSubtitle(_ minutes: Int) -> String {
        switch minutes {
        case 25: "sprint"
        case 45: "deep work"
        case 60: "one hour"
        case 120: "long block"
        case 240: "half day"
        default: "preset"
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
            range: 0...55,
            step: 5,
            isEnabled: model.customHours < FocusDuration.maximumHours,
            onChange: model.setCustomMinutes
        )
    }
}

private struct AppIdentityRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Focusward")
                    .font(.title2.weight(.semibold))
                Text("Make space for what you meant to do.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Local only", systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct DurationChoiceButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(
            isSelected ? Color.primary.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    isSelected ? Color.blue : Color.secondary.opacity(0.22),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
    }
}

private struct DurationStepper: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let step: Int
    var isEnabled = true
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.formatted())
                    .font(.title3.monospacedDigit())
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    onChange(max(range.lowerBound, value - step))
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled || value <= range.lowerBound)

                Button {
                    onChange(min(range.upperBound, value + step))
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled || value >= range.upperBound)
            }
        }
        .padding(12)
        .frame(minWidth: 190, maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .disabled(!isEnabled)
    }
}

private struct ActiveSessionView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        Form {
            Section {
                SessionSummary()
            }

            Section("Session Status") {
                StatusRow(
                    title: "Safari",
                    value: model.automationMessage,
                    systemImage: "safari"
                )
                StatusRow(
                    title: "Redirected",
                    value: "\(model.redirectedTabCount) tab\(model.redirectedTabCount == 1 ? "" : "s")",
                    systemImage: "arrow.turn.down.right"
                )
            }

            Section("Early End") {
                EarlyEndControls()
            }
        }
        .formStyle(.grouped)
    }
}

private struct SessionSummary: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Session Active")
                .font(.title2.weight(.semibold))

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(remainingText(at: context.date))
                    .font(.system(size: 46, weight: .medium, design: .monospaced))
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
        .padding(.vertical, 18)
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
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct EarlyEndControls: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        if let readyAt = model.earlyEndReadyAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if context.date >= readyAt {
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
                                Text("Available in \(cooldownText(until: readyAt, now: context.date))")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Cancel Request", action: model.cancelEarlyEnd)
                        }

                        ProgressView(
                            timerInterval: readyAt.addingTimeInterval(-90)...readyAt,
                            countsDown: false
                        )
                        .progressViewStyle(.linear)
                        .labelsHidden()
                        .tint(.blue)
                    }
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Need to stop?")
                        .fontWeight(.medium)
                    Text("Early ending takes 90 seconds and can be canceled.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Request Early End", action: model.requestEarlyEnd)
            }
        }
    }

    private func cooldownText(until date: Date, now: Date) -> String {
        "\(max(0, Int(ceil(date.timeIntervalSince(now)))))s"
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: FocuswardModel

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
            } else {
                Text("Focusward is ready")
                    .font(.headline)
            }

            Text(model.automationMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Focusward", systemImage: "macwindow")
            }

            if model.isSessionActive {
                if model.earlyEndReadyAt == nil {
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
