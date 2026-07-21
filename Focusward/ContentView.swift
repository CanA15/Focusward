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
        .padding(28)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SetupView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Focusward", systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Put a deliberate boundary between you and the next distracting tab.")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Blocked websites") {
                VStack(spacing: 12) {
                    HStack {
                        TextField("youtube.com", text: $model.draftDomain)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(model.addDraftDomain)
                        Button("Add", action: model.addDraftDomain)
                            .keyboardShortcut(.return, modifiers: [])
                    }

                    if model.domains.isEmpty {
                        ContentUnavailableView(
                            "No blocked websites",
                            systemImage: "globe",
                            description: Text("Add a domain to prepare your first session.")
                        )
                        .frame(minHeight: 180)
                    } else {
                        List {
                            ForEach(model.domains, id: \.self) { domain in
                                Label(domain, systemImage: "nosign")
                            }
                            .onDelete(perform: model.removeDomains)
                        }
                        .frame(minHeight: 180)
                    }
                }
                .padding(8)
            }

            HStack {
                Text("Session length")
                    .fontWeight(.semibold)
                Spacer()
                Picker("Session length", selection: $model.durationMinutes) {
                    ForEach(model.durationChoices, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            HStack {
                Label(model.automationMessage, systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button("Start Session", action: model.startSession)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.domains.isEmpty)
            }

            Text("Runs locally as your normal user. The first session asks for permission to control Safari—never for an administrator password.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ActiveSessionView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 28) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Focus session active")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(remainingText(at: context.date))
                        .font(.system(size: 44, weight: .medium, design: .monospaced))
                        .contentTransition(.numericText())
                }

                VStack(spacing: 8) {
                    Label(model.automationMessage, systemImage: "safari")
                    Text("\(model.redirectedTabCount) tab\(model.redirectedTabCount == 1 ? "" : "s") redirected this session")
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let readyAt = model.earlyEndReadyAt {
                    if context.date >= readyAt {
                        VStack(spacing: 12) {
                            Text("The cooldown is complete. Ending still requires confirmation.")
                                .multilineTextAlignment(.center)
                            HStack {
                                Button("Cancel", action: model.cancelEarlyEnd)
                                Button("End Session", role: .destructive, action: model.confirmEarlyEnd)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("Early end available in \(cooldownText(until: readyAt, at: context.date))")
                            ProgressView(
                                value: max(0, 90 - readyAt.timeIntervalSince(context.date)),
                                total: 90
                            )
                            Button("Cancel Request", action: model.cancelEarlyEnd)
                        }
                    }
                } else {
                    Button("Request Early End", action: model.requestEarlyEnd)
                        .buttonStyle(.bordered)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func remainingText(at date: Date) -> String {
        let seconds = max(0, Int((model.sessionEnd ?? date).timeIntervalSince(date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func cooldownText(until date: Date, at now: Date) -> String {
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

            if model.isSessionActive, model.earlyEndReadyAt == nil {
                Button("Request Early End", action: model.requestEarlyEnd)
            }

            Button("Quit Focusward") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private func remainingText(at date: Date) -> String {
        let seconds = max(0, Int((model.sessionEnd ?? date).timeIntervalSince(date)))
        return "\(seconds / 60)m \(seconds % 60)s remaining"
    }
}
