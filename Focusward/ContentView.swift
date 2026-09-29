import AppKit
import SwiftUI

struct ContentView: View {
    @Binding var selectedSection: FocuswardSection?

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 212, max: 260)
        } detail: {
            Group {
                switch selectedSection ?? .focusSession {
                case .focusSession:
                    FocusSessionView()
                case .dailyLimits:
                    DailyLimitsView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .help("Settings")
                }
            }
        }
    }
}

struct SectionCommands: Commands {
    @Binding var selectedSection: FocuswardSection?

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            ForEach(Array(FocuswardSection.allCases.enumerated()), id: \.element) { index, section in
                Button(section.rawValue) { selectedSection = section }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
            }
            Divider()
        }
    }
}

enum FocuswardSection: String, CaseIterable, Identifiable {
    case focusSession = "Focus Session"
    case dailyLimits = "Daily Limits"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .focusSession: "timer"
        case .dailyLimits: "cup.and.saucer"
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var model: FocuswardModel
    @Binding var selection: FocuswardSection?

    var body: some View {
        List(selection: $selection) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(FocuswardSection.focusSession.rawValue, systemImage: FocuswardSection.focusSession.systemImage)
                    .badge(sessionBadge(at: context.date))
            }
            .tag(FocuswardSection.focusSession)

            Label(FocuswardSection.dailyLimits.rawValue, systemImage: FocuswardSection.dailyLimits.systemImage)
                .badge(model.dailyLimits.isActive ? Text("On") : nil)
                .tag(FocuswardSection.dailyLimits)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProtectionStatus()
                .padding(10)
        }
    }

    private func sessionBadge(at date: Date) -> Text? {
        guard model.isSessionActive, let end = model.sessionEnd else { return nil }
        return Text(countdownText(seconds: max(0, Int(end.timeIntervalSince(date)))))
            .monospacedDigit()
    }
}

private struct ProtectionStatus: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: model.isProtectionActive ? "checkmark.shield.fill" : "shield")
                .font(.title3)
                .foregroundStyle(model.isProtectionActive ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.isProtectionActive ? "Protection On" : "Protection Off")
                    .font(.callout.weight(.semibold))
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // While a session runs, the session message has priority over the Daily Limits message.
    private var statusText: String {
        if !model.isSessionActive, model.dailyLimits.isActive {
            return model.dailyLimitsMessage
        }
        return model.automationMessage
    }
}

// MARK: - Focus Session

private struct FocusSessionView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        Form {
            Section {
                ForEach(model.domains, id: \.self) { domain in
                    WebsiteRow(domain: domain, isLocked: model.isSessionActive) {
                        withAnimation(.snappy) { model.removeDomain(domain) }
                    }
                }

                if model.domains.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                            .accessibilityHidden(true)
                        Text("No Blocked Websites")
                            .fontWeight(.semibold)
                        Text("Add a website to start a session.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
                // In a grouped form, only a section header can show content without a section background.
                VStack(spacing: 34) {
                    FocusHero()
                    HStack(alignment: .firstTextBaseline) {
                        Text("Blocked Websites")
                        Spacer()
                        Text(websiteCountText(model.domains.count))
                            .font(.callout.weight(.regular))
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(
                    model.isSessionActive
                        ? "You can change the websites after the session ends."
                        : "Subdomains are blocked too. Blocking applies to Safari, and your settings stay on this Mac."
                )
            }

            if model.isSessionActive {
                Section {
                    EarlyEndControls()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Focus Session")
    }
}

private struct FocusHero: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        VStack(spacing: 0) {
            if model.isSessionActive {
                activeContent
            } else {
                setupContent
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .font(.body.weight(.regular))
        .foregroundStyle(.primary)
        .animation(.smooth(duration: 0.35), value: model.isSessionActive)
        .animation(.smooth(duration: 0.3), value: model.usesCustomDuration)
    }

    private var setupContent: some View {
        Group {
            LargeTimeText(seconds: model.selectedDurationMinutes * 60, countsDown: false)

            TimelineView(.everyMinute) { context in
                Text(endText(for: context.date.addingTimeInterval(TimeInterval(model.selectedDurationMinutes * 60))))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            DurationPicker()
                .padding(.top, 22)

            if model.usesCustomDuration {
                HStack(spacing: 24) {
                    NumberStepper(
                        title: "Hours",
                        unit: "hr",
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
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.smooth(duration: 0.35)) { model.startSession() }
            } label: {
                Text("Start Session")
                    .fontWeight(.semibold)
                    .frame(minWidth: 124)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!model.canStartSession)
            .padding(.top, 22)

        }
    }

    private var activeContent: some View {
        Group {
            Label {
                Text("Blocking \(websiteCountText(model.domains.count)) in Safari")
            } icon: {
                Image(systemName: "shield.fill")
                    .foregroundStyle(.tint)
            }
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                LargeTimeText(seconds: remainingSeconds(at: context.date), countsDown: true)
            }
            .padding(.top, 12)

            if let end = model.sessionEnd {
                Text("\(endText(for: end)) · \(tabCountText(model.redirectedTabCount)) redirected")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    private func remainingSeconds(at date: Date) -> Int {
        max(0, Int((model.sessionEnd ?? date).timeIntervalSince(date)))
    }
}

private struct LargeTimeText: View {
    let seconds: Int
    let countsDown: Bool

    var body: some View {
        Text(countdownText(seconds: seconds))
            .font(.system(size: 80, weight: .thin).monospacedDigit())
            .tracking(-1.5)
            .contentTransition(.numericText(countsDown: countsDown))
            .animation(.snappy, value: seconds)
    }
}

private enum DurationOption: Hashable {
    case preset(Int)
    case custom
}

private struct DurationPicker: View {
    @EnvironmentObject private var model: FocuswardModel

    private var selection: Binding<DurationOption> {
        Binding(
            get: { model.usesCustomDuration ? .custom : .preset(model.durationMinutes) },
            set: { option in
                withAnimation(.snappy(duration: 0.3)) {
                    switch option {
                    case .preset(let minutes): model.selectDurationPreset(minutes)
                    case .custom: model.selectCustomDuration()
                    }
                }
            }
        )
    }

    var body: some View {
        Picker("Session length", selection: selection) {
            ForEach(FocusDuration.presets, id: \.self) { minutes in
                Text(FocusDuration.compactLabel(totalMinutes: minutes))
                    .tag(DurationOption.preset(minutes))
            }
            Text("Custom")
                .tag(DurationOption.custom)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

private struct EarlyEndControls: View {
    @State private var isConfirming = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("End Session Early")
                Text("You confirm, and then you hold a button for \(Int(HoldToConfirmButton.duration)) seconds.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("End Session…") { isConfirming = true }
                .buttonBorderShape(.capsule)
        }
        .sheet(isPresented: $isConfirming) {
            EndSessionSheet()
        }
    }
}

private struct EndSessionSheet: View {
    private enum Step {
        case confirm
        case hold
    }

    @EnvironmentObject private var model: FocuswardModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.confirm

    var body: some View {
        AlertSheetLayout(title: step == .confirm ? "End the Session Early?" : "Hold to End the Session") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("The session has \(FocusDuration.label(totalMinutes: minutesLeft(at: context.date))) left. All blocked websites open again.")
            }
        } actions: {
            switch step {
            case .confirm:
                AlertConfirmationButtons(cancelTitle: "Keep Session") {
                    step = .hold
                }
            case .hold:
                AlertHoldButtons(buttonTitle: "Hold to End Session", cancelTitle: "Keep Session") {
                    withAnimation(.smooth(duration: 0.35)) { model.endSessionEarly() }
                    dismiss()
                }
            }
        }
    }

    private func minutesLeft(at date: Date) -> Int {
        let seconds = (model.sessionEnd ?? date).timeIntervalSince(date)
        return max(0, Int((seconds / 60).rounded(.up)))
    }
}

// MARK: - Daily Limits

private struct DailyLimitsView: View {
    @EnvironmentObject private var model: FocuswardModel
    @State private var confirmation: DailyConfirmation?

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { model.dailyLimits.isActive },
            set: { active in
                if active {
                    withAnimation(.snappy) { model.setDailyLimitsActive(true) }
                } else {
                    confirmation = .turnOff
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: activeBinding) {
                    Text("Daily Limits")
                    Text("Listed websites stay blocked. A break opens one website for a set time.")
                }
                .toggleStyle(.switch)
                .disabled(!model.canActivateDailyLimits && !model.dailyLimits.isActive)

                LabeledContent("Status", value: model.dailyLimitsMessage)

                if model.dailyLimits.isActive {
                    LabeledContent("Redirected", value: tabCountText(model.dailyRedirectedTabCount))
                }
            }

            Section {
                ForEach(model.dailyLimits.sites) { site in
                    DailyLimitRow(site: site) {
                        confirmation = .startBreak(domain: site.domain)
                    }
                }

                if !model.dailyLimits.isActive {
                    AddWebsiteRow(
                        text: $model.dailyDraftDomain,
                        accessibilityLabel: "Website for a daily limit"
                    ) {
                        withAnimation(.snappy) { model.addDailyDraftSite() }
                    } accessory: {
                        NumberStepper(
                            title: "Break time per day",
                            unit: "min",
                            value: model.dailyDraftAllowanceMinutes,
                            range: DailyLimits.allowanceRange,
                            step: 5,
                            onChange: model.setDailyDraftAllowanceMinutes
                        )
                    }
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Websites")
                    Spacer()
                    Text("Break time per day")
                        .font(.callout.weight(.regular))
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(websitesFooter)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Daily Limits")
        .sheet(item: $confirmation) { confirmation in
            switch confirmation {
            case .startBreak(let domain):
                BreakRequestSheet(domain: domain)
            case .turnOff:
                TurnOffDailyLimitsSheet()
            }
        }
        .task {
            while !Task.isCancelled {
                model.refreshDailyLimits()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var websitesFooter: String {
        if model.dailyLimits.isActive {
            return "Break time resets at midnight. Turn off Daily Limits to change the websites."
        }
        if !model.canActivateDailyLimits {
            return "Add a website to turn on Daily Limits. Each rule also applies to its subdomains."
        }
        return "Each rule also applies to its subdomains. Break time resets at midnight."
    }
}

private struct DailyLimitRow: View {
    @EnvironmentObject private var model: FocuswardModel
    let site: DailyLimitSite
    let onTakeBreak: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            WebsiteTileView(domain: site.domain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(site.domain)
                    if model.dailyLimits.isActive {
                        Text("\(site.allowanceMinutes) min")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(statusText(at: context.date))
                        .font(.callout.weight(site.activeBreak == nil ? .regular : .medium))
                        .foregroundStyle(statusStyle)
                        .monospacedDigit()
                }
                ProgressView(value: min(max(site.usedSeconds / site.allowanceSeconds, 0), 1))
                    .progressViewStyle(.linear)
                    .labelsHidden()
                    .controlSize(.small)
                    .tint(isOutOfBreakTime ? Color.red : Color.accentColor)
                    .frame(maxWidth: 260)
                    .padding(.top, 2)
                    .animation(.smooth, value: site.usedSeconds)
            }

            Spacer()

            if !model.dailyLimits.isActive {
                NumberStepper(
                    title: "Break time per day for \(site.domain)",
                    unit: "min",
                    value: site.allowanceMinutes,
                    range: DailyLimits.allowanceRange,
                    step: 5,
                    onChange: { model.updateDailyAllowance(for: site.domain, minutes: $0) }
                )
                RemoveButton(domain: site.domain, action: remove)
                    .opacity(isHovered ? 1 : 0)
            } else if site.activeBreak != nil {
                Button("End Break") {
                    withAnimation(.snappy) { model.endDailyBreak(for: site.domain) }
                }
                .buttonBorderShape(.capsule)
            } else {
                Button("Take a Break…", action: onTakeBreak)
                    .buttonBorderShape(.capsule)
                    .disabled(!model.canStartDailyBreak(for: site.domain))
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            if !model.dailyLimits.isActive {
                Button("Remove \(site.domain)", role: .destructive, action: remove)
            }
        }
    }

    private var isOutOfBreakTime: Bool {
        site.activeBreak == nil && site.remainingMinutes == 0
    }

    private var statusStyle: AnyShapeStyle {
        if site.activeBreak != nil {
            return AnyShapeStyle(.tint)
        }
        return isOutOfBreakTime ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary)
    }

    private func remove() {
        withAnimation(.snappy) { model.removeDailyLimit(for: site.domain) }
    }

    private func statusText(at date: Date) -> String {
        if let activeBreak = site.activeBreak {
            return "On a break · \(countdownText(seconds: activeBreak.secondsLeft(at: date))) left"
        }
        if model.dailyLimits.isActive, model.isBlockedBySession(site.domain) {
            return "Blocked by the focus session"
        }
        if site.remainingMinutes == 0 {
            return "No break time left today"
        }
        return "\(site.remainingMinutes) min left today"
    }
}

private enum DailyConfirmation: Identifiable {
    case startBreak(domain: String)
    case turnOff

    var id: String {
        switch self {
        case .startBreak(let domain): domain
        case .turnOff: "turnOff"
        }
    }
}

private struct BreakRequestSheet: View {
    private enum Step {
        case length
        case confirm
        case hold
    }

    @EnvironmentObject private var model: FocuswardModel
    @Environment(\.dismiss) private var dismiss
    let domain: String
    @State private var step = Step.length
    @State private var breakMinutes: Int?
    @State private var failure: String?

    private var site: DailyLimitSite? {
        model.dailyLimits.site(for: domain)
    }

    private var breakLengthOptions: [Int] {
        site?.breakLengthOptions ?? []
    }

    private var selectedBreakMinutes: Int {
        if let breakMinutes, breakLengthOptions.contains(breakMinutes) {
            return breakMinutes
        }
        return site?.defaultBreakMinutes ?? 0
    }

    private var stepNumber: Int {
        switch step {
        case .length: 1
        case .confirm: 2
        case .hold: 3
        }
    }

    private var breakLengthSelection: Binding<Int> {
        Binding(
            get: { selectedBreakMinutes },
            set: { breakMinutes = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                WebsiteTileView(domain: domain, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Text("Step \(stepNumber) of 3 · \(site?.remainingMinutes ?? 0) min of break time left today")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            switch step {
            case .length:
                lengthStep
            case .confirm:
                confirmStep
            case .hold:
                HoldStep(
                    buttonTitle: "Hold to Start Break",
                    failure: failure,
                    onComplete: startBreak
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(width: 440)
    }

    private var title: String {
        switch step {
        case .length: "Take a Break from \(domain)"
        case .confirm: "Are You Sure?"
        case .hold: "Hold to Start the Break"
        }
    }

    private var afterBreakText: String {
        let minutesLeft = site?.remainingMinutes(afterBreakOf: selectedBreakMinutes) ?? 0
        return "After this break, you will have \(minutesLeft) min of break time left today."
    }

    private var lengthStep: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                Text("Break length")
                    .fontWeight(.semibold)
                Picker("Break length", selection: breakLengthSelection) {
                    ForEach(breakLengthOptions, id: \.self) { minutes in
                        Text(minutes == breakLengthOptions.last ? "All \(minutes) min" : "\(minutes) min")
                            .tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(afterBreakText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ConfirmationButtons(cancelTitle: "Cancel", continueTitle: "Continue") {
                step = .confirm
            }
        }
    }

    private var confirmStep: some View {
        Group {
            if let site {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You took \(breakCountText(site.breakCount)) on \(site.domain) today. You used \(site.usedMinutes) of \(site.allowanceMinutes) minutes.")
                    Text(afterBreakText)
                        .foregroundStyle(.secondary)
                }
            }

            ConfirmationButtons(cancelTitle: "Not Now", continueTitle: "Yes, Continue") {
                step = .hold
            }
        }
    }

    private func startBreak() {
        do {
            try withAnimation(.snappy) {
                try model.startDailyBreak(for: domain, minutes: selectedBreakMinutes)
            }
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }

    private func breakCountText(_ count: Int) -> String {
        switch count {
        case 0: "no breaks"
        case 1: "1 break"
        default: "\(count) breaks"
        }
    }
}

private struct TurnOffDailyLimitsSheet: View {
    private enum Step {
        case confirm
        case hold
    }

    @EnvironmentObject private var model: FocuswardModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.confirm

    var body: some View {
        AlertSheetLayout(title: step == .confirm ? "Turn Off Daily Limits?" : "Hold to Turn Off Daily Limits") {
            Text("All listed websites open with no limit until you turn on Daily Limits again. A break in progress ends.")
        } actions: {
            switch step {
            case .confirm:
                AlertConfirmationButtons(cancelTitle: "Keep On") {
                    step = .hold
                }
            case .hold:
                AlertHoldButtons(buttonTitle: "Hold to Turn Off", cancelTitle: "Keep On") {
                    withAnimation(.snappy) { model.setDailyLimitsActive(false) }
                    dismiss()
                }
            }
        }
    }
}

// The layout follows a macOS alert: the app icon, a title, a message, and full-width buttons.
private struct AlertSheetLayout<Message: View, Actions: View>: View {
    let title: String
    @ViewBuilder let message: Message
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .padding(.top, 12)
            message
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            actions
                .padding(.top, 18)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .frame(width: 320)
    }
}

private struct AlertConfirmationButtons: View {
    @Environment(\.dismiss) private var dismiss
    let cancelTitle: String
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(role: .cancel) { dismiss() } label: {
                Text(cancelTitle)
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.cancelAction)
            Button {
                withAnimation(.snappy) { onContinue() }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
    }
}

private struct AlertHoldButtons: View {
    @Environment(\.dismiss) private var dismiss
    let buttonTitle: String
    let cancelTitle: String
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HoldToConfirmButton(title: buttonTitle, tint: .red, action: onComplete)
            Text("Hold for \(Int(HoldToConfirmButton.duration)) seconds. If you release early, the progress resets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Button(role: .cancel) { dismiss() } label: {
                Text(cancelTitle)
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.large)
            .padding(.top, 14)
        }
    }
}

private struct HoldStep: View {
    @Environment(\.dismiss) private var dismiss
    let buttonTitle: String
    let failure: String?
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HoldToConfirmButton(title: buttonTitle, tint: .accentColor, action: onComplete)
            Text("Hold the button for \(Int(HoldToConfirmButton.duration)) seconds. If you release it early, the progress resets.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }

        if let failure {
            Text(failure)
                .foregroundStyle(.red)
        }

        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }
}

private struct ConfirmationButtons: View {
    @Environment(\.dismiss) private var dismiss
    let cancelTitle: String
    let continueTitle: String
    let onContinue: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(cancelTitle, role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(continueTitle) {
                withAnimation(.snappy) { onContinue() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// A long press has no keyboard equivalent. See docs/ARCHITECTURE.md.
private struct HoldToConfirmButton: View {
    static let duration: TimeInterval = 5

    let title: String
    let tint: Color
    let action: () -> Void
    @State private var pressStart: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: pressStart == nil)) { context in
            Text(label(at: context.date))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(tint)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.3))
                        .scaleEffect(x: pressStart == nil ? 0 : 1, anchor: .leading)
                }
                .clipShape(Capsule())
        }
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: Self.duration, maximumDistance: 40) {
            action()
        } onPressingChanged: { pressing in
            withAnimation(pressing ? .linear(duration: Self.duration) : .easeOut(duration: 0.2)) {
                pressStart = pressing ? Date() : nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint("Press and hold for \(Int(Self.duration)) seconds.")
        .accessibilityAddTraits(.isButton)
    }

    private func label(at date: Date) -> String {
        guard let pressStart else { return title }
        let secondsLeft = max(1, Int((Self.duration - date.timeIntervalSince(pressStart)).rounded(.up)))
        return "Keep Holding · \(secondsLeft) s"
    }
}

// MARK: - Shared controls

private struct WebsiteRow: View {
    let domain: String
    let isLocked: Bool
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            WebsiteTileView(domain: domain)
            Text(domain)
                .textSelection(.enabled)
            Spacer()
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Locked")
            } else {
                // The button stays in the layout and in the accessibility tree when it is hidden.
                RemoveButton(domain: domain, action: onRemove)
                    .opacity(isHovered ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            if !isLocked {
                Button("Remove \(domain)", role: .destructive, action: onRemove)
            }
        }
    }
}

private struct WebsiteTileView: View {
    private static let colors: [Color] = [.pink, .orange, .gray, .red, .cyan, .indigo, .green, .purple]

    let domain: String
    var size: CGFloat = 24

    var body: some View {
        Text(WebsiteTile.letter(for: domain))
            .font(.system(size: size / 2, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Self.colors[WebsiteTile.colorIndex(for: domain) % Self.colors.count].gradient,
                in: RoundedRectangle(cornerRadius: size / 4, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

private struct AddWebsiteRow<Accessory: View>: View {
    @Binding var text: String
    let accessibilityLabel: String
    let onAdd: () -> Void
    @ViewBuilder let accessory: Accessory

    private var canAdd: Bool {
        DomainMatcher.normalizeRule(text) != nil
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
                .accessibilityHidden(true)
            TextField(accessibilityLabel, text: $text, prompt: Text("Add a website, such as youtube.com"))
                .textFieldStyle(.plain)
                .labelsHidden()
                .onSubmit {
                    if canAdd { onAdd() }
                }
            accessory
            Button("Add", action: onAdd)
                .buttonBorderShape(.capsule)
                .disabled(!canAdd)
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

// MARK: - Menu bar

struct MenuBarContentView: View {
    @EnvironmentObject private var model: FocuswardModel
    @Environment(\.openSettings) private var openSettings
    let showMainWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text("Focusward")
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(model.isProtectionActive ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(model.isProtectionActive ? "On" : "Off")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)

            VStack(spacing: 6) {
                if model.isSessionActive {
                    sessionCard
                }
                if model.dailyLimits.isActive {
                    dailyLimitsCard
                }
                if !model.isProtectionActive {
                    Text("No session or daily limit is active.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 4)

            Divider()
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                Button("Open Focusward", action: showMainWindow)

                ForEach(model.dailyLimits.sitesOnBreak) { site in
                    Button("End Break for \(site.domain)") {
                        model.endDailyBreak(for: site.domain)
                    }
                }

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    MenuRowTitle(title: "Settings…", shortcut: "⌘,")
                }

                Divider()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    MenuRowTitle(title: "Quit Focusward", shortcut: "⌘Q")
                }
            }
            .buttonStyle(MenuRowButtonStyle())
        }
        .padding(6)
        .frame(width: 300)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Focus Session")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(countdownText(seconds: max(0, Int((model.sessionEnd ?? context.date).timeIntervalSince(context.date)))))
                    .font(.system(size: 34, weight: .light).monospacedDigit())
                    .tracking(-0.5)
            }
            if let end = model.sessionEnd {
                Text("\(endText(for: end)) · \(tabCountText(model.redirectedTabCount)) redirected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(model.automationMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var dailyLimitsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Limits")
                    .fontWeight(.semibold)
                Spacer()
                Text(websiteCountText(model.dailyLimits.sites.count))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !model.isSessionActive || model.dailyLimitsMessage != model.automationMessage {
                Text(model.dailyLimitsMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ForEach(model.dailyLimits.sitesOnBreak) { site in
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 8) {
                        Image(systemName: "cup.and.saucer")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(site.domain)
                        Spacer()
                        Text(countdownText(seconds: site.activeBreak?.secondsLeft(at: context.date) ?? 0))
                            .fontWeight(.medium)
                            .foregroundStyle(.tint)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MenuRowTitle: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            // The row color changes on hover, so the shortcut uses an opacity of that color.
            Text(shortcut)
                .opacity(0.55)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Show the break timer in the notch",
                    isOn: Binding(
                        get: { model.showsNotchBreakTimer },
                        set: { model.setShowsNotchBreakTimer($0) }
                    )
                )
            } footer: {
                Text("While a Daily Limits break runs, move the pointer to the notch to see the time left, to end a break, or to open Focusward. A display without a notch does not show the timer.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
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
                .padding(.horizontal, 10)
                .frame(height: 26)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
                .background(
                    isHovered ? Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
        }
    }
}

// MARK: - Formatting

func countdownText(seconds: Int) -> String {
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

private func websiteCountText(_ count: Int) -> String {
    "\(count) website\(count == 1 ? "" : "s")"
}
