import AppKit
import SwiftUI

private let focuswardGreen = Color(red: 0.20, green: 0.63, blue: 0.40)

struct ContentView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            LinearGradient(
                colors: [focuswardGreen.opacity(0.10), .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if model.isSessionActive {
                ActiveSessionView()
            } else {
                SetupView()
            }
        }
    }
}

private struct SetupView: View {
    @EnvironmentObject private var model: FocuswardModel

    private let durationColumns = [
        GridItem(.adaptive(minimum: 88), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppHeader()

                FocuswardCard(
                    title: "Blocked websites",
                    subtitle: "A rule also covers every subdomain.",
                    systemImage: "globe"
                ) {
                    HStack(spacing: 10) {
                        TextField("youtube.com", text: $model.draftDomain)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(model.addDraftDomain)

                        Button("Add", action: model.addDraftDomain)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.return, modifiers: [])
                    }

                    if model.domains.isEmpty {
                        HStack(spacing: 14) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Your blocklist is empty")
                                    .fontWeight(.medium)
                                Text("Add the sites that tend to pull you off course.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.domains, id: \.self) { domain in
                                HStack(spacing: 10) {
                                    Image(systemName: "nosign")
                                        .foregroundStyle(focuswardGreen)
                                    Text(domain)
                                        .textSelection(.enabled)
                                    Spacer()
                                    Button {
                                        model.removeDomain(domain)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.secondary)
                                    .help("Remove \(domain)")
                                }
                                .padding(.vertical, 10)

                                if domain != model.domains.last {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                FocuswardCard(
                    title: "Session length",
                    subtitle: "Choose a quick duration or make your own.",
                    systemImage: "timer"
                ) {
                    LazyVGrid(columns: durationColumns, spacing: 10) {
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
                        HStack(spacing: 12) {
                            DurationStepper(
                                title: "Hours",
                                value: model.customHours,
                                range: 0...FocusDuration.maximumHours,
                                step: 1,
                                onChange: model.setCustomHours
                            )

                            DurationStepper(
                                title: "Minutes",
                                value: model.customMinutes,
                                range: 0...55,
                                step: 5,
                                isEnabled: model.customHours < FocusDuration.maximumHours,
                                onChange: model.setCustomMinutes
                            )
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    HStack {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(model.selectedDurationMinutes > 0 ? model.durationSummary : "Choose a duration")
                            .fontWeight(.semibold)
                            .foregroundStyle(model.selectedDurationMinutes > 0 ? Color.primary : Color.red)
                    }
                    .font(.callout)
                }

                HStack(spacing: 16) {
                    Label(model.automationMessage, systemImage: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 16)

                    Button(action: model.startSession) {
                        Label("Start Session", systemImage: "arrow.right")
                            .frame(minWidth: 112)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(focuswardGreen)
                    .disabled(!model.canStartSession)
                }
                .padding(.top, 2)

                Text("Everything stays on this Mac. Focusward asks to control Safari, never for an administrator password.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 680)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
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
}

private struct AppHeader: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [focuswardGreen, focuswardGreen.opacity(0.70)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)
            .shadow(color: focuswardGreen.opacity(0.24), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text("Focusward")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Make space for what you meant to do.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Local only", systemImage: "checkmark.shield")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(focuswardGreen.opacity(0.10), in: Capsule())
                .foregroundStyle(focuswardGreen)
        }
        .padding(.bottom, 4)
    }
}

private struct FocuswardCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(focuswardGreen)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .padding(18)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.82),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
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
            VStack(spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? focuswardGreen : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? focuswardGreen.opacity(0.13) : Color.clear,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isSelected ? focuswardGreen : Color.secondary.opacity(0.20), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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
                Text("\(value)")
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
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .disabled(!isEnabled)
    }
}

private struct ActiveSessionView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Label("Focusward", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                        Spacer()
                        Text("SESSION ACTIVE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(focuswardGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(focuswardGreen.opacity(0.10), in: Capsule())
                    }

                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(focuswardGreen.opacity(0.12))
                            Image(systemName: "shield.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(focuswardGreen)
                        }
                        .frame(width: 86, height: 86)

                        VStack(spacing: 7) {
                            Text("Stay with what matters")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(remainingText(at: context.date))
                                .font(.system(size: 48, weight: .medium, design: .monospaced))
                                .contentTransition(.numericText())
                                .minimumScaleFactor(0.65)
                                .lineLimit(1)

                            if let end = model.sessionEnd {
                                Text("Ends \(end.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(
                        Color(nsColor: .controlBackgroundColor).opacity(0.84),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }

                    HStack(spacing: 12) {
                        StatusTile(
                            title: "Safari",
                            value: model.automationMessage,
                            systemImage: "safari"
                        )
                        StatusTile(
                            title: "Redirected",
                            value: "\(model.redirectedTabCount) tab\(model.redirectedTabCount == 1 ? "" : "s")",
                            systemImage: "arrow.turn.down.right"
                        )
                    }

                    EarlyEndCard(now: context.date)
                }
                .frame(maxWidth: 680)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
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

private struct StatusTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(focuswardGreen)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct EarlyEndCard: View {
    @EnvironmentObject private var model: FocuswardModel
    let now: Date

    var body: some View {
        VStack(spacing: 12) {
            if let readyAt = model.earlyEndReadyAt {
                if now >= readyAt {
                    Text("The cooldown is complete. Ending still requires confirmation.")
                        .multilineTextAlignment(.center)
                    HStack {
                        Button("Keep Session", action: model.cancelEarlyEnd)
                        Button("End Session", role: .destructive, action: model.confirmEarlyEnd)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Early-end cooldown")
                                .fontWeight(.semibold)
                            Text("Available in \(cooldownText(until: readyAt))")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Cancel Request", action: model.cancelEarlyEnd)
                    }
                    ProgressView(
                        value: max(0, 90 - readyAt.timeIntervalSince(now)),
                        total: 90
                    )
                    .tint(focuswardGreen)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Need to stop?")
                            .fontWeight(.semibold)
                        Text("Early ending takes 90 seconds and can be canceled.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Request Early End", action: model.requestEarlyEnd)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func cooldownText(until date: Date) -> String {
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

            Button("Open Focusward") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            if model.isSessionActive {
                if model.earlyEndReadyAt == nil {
                    Button("Request Early End", action: model.requestEarlyEnd)
                } else {
                    Button("Cancel Early-End Request", action: model.cancelEarlyEnd)
                }
            }

            Button("Quit Focusward") {
                NSApp.terminate(nil)
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
