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

            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
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
                    ZStack {
                        // A session from an earlier version has no saved start time.
                        if let start = model.sessionStart, let end = model.sessionEnd {
                            let fraction = FocusDuration.remainingFraction(start: start, end: end, at: context.date)
                            Circle()
                                .stroke(.quaternary, lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: fraction)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: fraction)
                        }

                        Text(countdownText(seconds: remainingSeconds(at: context.date)))
                            .font(.system(size: 64, weight: .light).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, 36)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.snappy, value: remainingSeconds(at: context.date))
                    }
                    .frame(width: 280, height: 280)
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

private enum DurationOption: Hashable {
    case preset(Int)
    case custom
}

private struct DurationPicker: View {
    @EnvironmentObject private var model: FocuswardModel

    var body: some View {
        CapsulePicker(
            options: FocusDuration.presets.map(DurationOption.preset) + [.custom],
            selection: model.usesCustomDuration ? .custom : .preset(model.durationMinutes),
            title: { option in
                switch option {
                case .preset(let minutes): FocusDuration.compactLabel(totalMinutes: minutes)
                case .custom: "Custom"
                }
            },
            onSelect: { option in
                switch option {
                case .preset(let minutes): model.selectDurationPreset(minutes)
                case .custom: model.selectCustomDuration()
                }
            }
        )
    }
}

private struct EarlyEndControls: View {
    @State private var isConfirming = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Need to stop?")
                Text("To end the session early, you confirm and then hold a button.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("End Session Early…") { isConfirming = true }
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
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case .confirm:
                Text("End the Session Early?")
                    .font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("The session has \(FocusDuration.label(totalMinutes: minutesLeft(at: context.date))) left. All blocked websites open again.")
                        .foregroundStyle(.secondary)
                }

                ConfirmationButtons(cancelTitle: "Keep Session", continueTitle: "Continue") {
                    step = .hold
                }
            case .hold:
                HoldStep(
                    title: "Hold to End the Session",
                    buttonTitle: "Hold to End",
                    failure: nil
                ) {
                    withAnimation(.smooth(duration: 0.35)) { model.endSessionEarly() }
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 380)
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
                    Text("Listed websites stay blocked. Take a break to open a website for a set time.")
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
                Text("Websites")
            } footer: {
                Text("Each rule also applies to its subdomains. The minutes are the break time for each day.")
            }
        }
        .formStyle(.grouped)
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

    private var protectionFooter: String {
        if model.dailyLimits.isActive {
            return "Break time resets at midnight. Turn off Daily Limits to change the websites."
        }
        if !model.canActivateDailyLimits {
            return "Add a website below to turn on Daily Limits."
        }
        return "Break time resets at midnight."
    }
}

private struct DailyLimitRow: View {
    @EnvironmentObject private var model: FocuswardModel
    let site: DailyLimitSite
    let onTakeBreak: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.domain)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(statusText(at: context.date))
                            .font(.callout)
                            .foregroundStyle(isOutOfBreakTime ? Color.red : Color.secondary)
                            .monospacedDigit()
                    }
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
                    RemoveButton(domain: site.domain) {
                        withAnimation(.snappy) { model.removeDailyLimit(for: site.domain) }
                    }
                } else if site.activeBreak != nil {
                    Button("End Break") {
                        withAnimation(.snappy) { model.endDailyBreak(for: site.domain) }
                    }
                } else {
                    Button("Take a Break", action: onTakeBreak)
                        .disabled(!model.canStartDailyBreak(for: site.domain))
                }
            }

            ProgressView(value: min(max(site.usedSeconds / site.allowanceSeconds, 0), 1))
                .progressViewStyle(.linear)
                .labelsHidden()
                .tint(isOutOfBreakTime ? Color.red : Color.accentColor)
                .animation(.smooth, value: site.usedSeconds)
        }
        .padding(.vertical, 4)
    }

    private var isOutOfBreakTime: Bool {
        site.activeBreak == nil && site.remainingMinutes == 0
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
        return "\(site.remainingMinutes) min of break time left today"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case .length:
                lengthStep
            case .confirm:
                confirmStep
            case .hold:
                HoldStep(
                    title: "Hold to Start the Break",
                    buttonTitle: "Hold to Start",
                    failure: failure,
                    onComplete: startBreak
                )
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private var lengthStep: some View {
        Group {
            Text("Take a Break from \(domain)")
                .font(.headline)

            CapsulePicker(
                options: breakLengthOptions,
                selection: selectedBreakMinutes,
                title: { minutes in
                    minutes == breakLengthOptions.last ? "All \(minutes) min" : "\(minutes) min"
                },
                onSelect: { breakMinutes = $0 }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Break length")

            Text("\(site?.remainingMinutes ?? 0) min of break time left today.")
                .foregroundStyle(.secondary)

            ConfirmationButtons(cancelTitle: "Cancel", continueTitle: "Continue") {
                step = .confirm
            }
        }
    }

    private var confirmStep: some View {
        Group {
            Text("Are You Sure?")
                .font(.headline)

            if let site {
                Text("You took \(breakCountText(site.breakCount)) on \(site.domain) today. You used \(site.usedMinutes) of \(site.allowanceMinutes) minutes.")
                Text("After this break, you will have \(site.remainingMinutes(afterBreakOf: selectedBreakMinutes)) min of break time left today.")
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case .confirm:
                Text("Turn Off Daily Limits?")
                    .font(.headline)
                Text("All listed websites open with no limit until you turn on Daily Limits again. A break in progress ends.")
                    .foregroundStyle(.secondary)

                ConfirmationButtons(cancelTitle: "Keep On", continueTitle: "Continue") {
                    step = .hold
                }
            case .hold:
                HoldStep(
                    title: "Hold to Turn Off Daily Limits",
                    buttonTitle: "Hold to Turn Off",
                    failure: nil
                ) {
                    withAnimation(.snappy) { model.setDailyLimitsActive(false) }
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

private struct HoldStep: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let buttonTitle: String
    let failure: String?
    let onComplete: () -> Void

    var body: some View {
        Text(title)
            .font(.headline)

        HoldToConfirmButton(title: buttonTitle, action: onComplete)
            .frame(maxWidth: .infinity)

        Text("Hold for \(Int(HoldToConfirmButton.duration)) seconds. Releasing early resets the progress.")
            .font(.callout)
            .foregroundStyle(.secondary)

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
    let action: () -> Void
    @State private var isPressing = false

    var body: some View {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 200)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background {
                Capsule()
                    .fill(Color.accentColor.opacity(0.45))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentColor)
                            .scaleEffect(x: isPressing ? 1 : 0, anchor: .leading)
                    }
                    .clipShape(Capsule())
            }
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: Self.duration, maximumDistance: 40) {
                action()
            } onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: Self.duration) : .easeOut(duration: 0.2)) {
                    isPressing = pressing
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityHint("Press and hold for \(Int(Self.duration)) seconds.")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Shared controls

private struct CapsulePicker<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let onSelect: (Option) -> Void
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.3)) { onSelect(option) }
                } label: {
                    Text(title(option))
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
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

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
                        ForEach(model.dailyLimits.sitesOnBreak) { site in
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                HStack {
                                    Text("Break · \(site.domain)")
                                    Spacer()
                                    Text(countdownText(seconds: site.activeBreak?.secondsLeft(at: context.date) ?? 0))
                                        .monospacedDigit()
                                }
                                .font(.caption)
                            }
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

                ForEach(model.dailyLimits.sitesOnBreak) { site in
                    Button {
                        model.endDailyBreak(for: site.domain)
                    } label: {
                        Label("End Break for \(site.domain)", systemImage: "cup.and.saucer")
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
