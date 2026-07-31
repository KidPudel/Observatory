import AppKit
import Charts
import ObservatoryDomain
import SwiftUI

struct SessionsView: View {
    @ObservedObject var model: SessionsViewModel
    @ObservedObject var historyModel: HistoryViewModel
    @State private var showsAdvanced = false
    @State private var showsCancellationOptions = false
    @State private var showsSavedResults: Bool
    @State private var showsCompactSavedResults = true
    @AppStorage(AppPreferenceKeys.savedResultsPanelSide)
    private var savedResultsPanelSide = "right"
    let onInitialExpansionConsumed: () -> Void

    init(
        model: SessionsViewModel,
        historyModel: HistoryViewModel,
        initiallyShowsSavedResults: Bool = false,
        onInitialExpansionConsumed: @escaping () -> Void = {}
    ) {
        self.model = model
        self.historyModel = historyModel
        self.onInitialExpansionConsumed = onInitialExpansionConsumed
        _showsSavedResults = State(
            initialValue: initiallyShowsSavedResults
        )
    }

    var body: some View {
        FloatingPage {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    DestinationCaption(text: AppDestination.sessions.caption)

                    Spacer()

                    TestsWorkspaceSwitcher(
                        showsSavedResults: showsSavedResults,
                        canBrowseSavedResults: canBrowseSavedResults,
                        showNewTest: showNewTest,
                        showSavedResults: showSavedResults
                    )
                }

                if let error = model.errorMessage {
                    SessionNotice(
                        message: error,
                        isError: true,
                        onDismiss: model.dismissError
                    )
                }
                if let notice = model.engineState.notice {
                    SessionNotice(
                        message: notice,
                        isError: false,
                        onDismiss: model.dismissNotice
                    )
                }

                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .task {
            await model.run()
        }
        .confirmationDialog(
            "Cancel this controlled test?",
            isPresented: $showsCancellationOptions,
            titleVisibility: .visible
        ) {
            Button("Preserve partial result") {
                model.cancel(preservingPartialResult: true)
            }
            Button("Discard test and samples", role: .destructive) {
                model.cancel(preservingPartialResult: false)
            }
            Button("Keep testing", role: .cancel) {}
        } message: {
            Text("You can preserve completed rounds and samples recorded so far.")
        }
        .onChange(of: model.engineState.session?.status) {
            guard !canBrowseSavedResults else { return }
            showsSavedResults = false
            historyModel.closePresentation()
        }
        .onAppear {
            if showsSavedResults {
                onInitialExpansionConsumed()
            }
        }
        .animation(.easeOut(duration: 0.14), value: showsSavedResults)
    }

    private func showNewTest() {
        historyModel.leaveSavedResults()
        showsSavedResults = false
        showsCompactSavedResults = true
        if model.selectedResult != nil {
            model.closeResult()
        }
    }

    private func showSavedResults() {
        guard canBrowseSavedResults else { return }
        historyModel.closePresentation()
        showsSavedResults = true
        showsCompactSavedResults = true
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            SessionSurface {
                ProgressView("Loading monitoring studio…")
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        } else if model.engineState.recoveryRequired {
            RecoveryPanel(
                state: model.engineState,
                onContinue: model.acceptRecovery,
                onDiscard: model.discardRecovery
            )
        } else if historyModel.hasOpenPresentation {
            historicalInspection
        } else if showsSavedResults {
            SavedResultsLibrary(model: historyModel)
        } else if let result = model.selectedResult {
            ResultPanel(result: result, onClose: model.closeResult)
        } else if model.engineState.session != nil {
            ActiveTestPanel(
                state: model.engineState,
                isWorking: model.isWorking,
                onBegin: model.beginCurrentRound,
                onSkip: model.skipCurrentRound,
                onRetry: model.retryRound,
                onFinishPartial: model.finishPartial,
                onCancel: { showsCancellationOptions = true }
            )
        } else {
            SetupPanel(
                model: model,
                showsAdvanced: $showsAdvanced
            )
        }
    }

    private var historicalInspection: some View {
        HStack(alignment: .top, spacing: 16) {
            if showsCompactSavedResults && compactPanelIsLeading {
                compactSavedResultsPanel
            }

            inspectionMain

            if showsCompactSavedResults && !compactPanelIsLeading {
                compactSavedResultsPanel
            }
        }
        .animation(
            .easeOut(duration: 0.14),
            value: showsCompactSavedResults
        )
        .animation(.easeOut(duration: 0.14), value: compactPanelIsLeading)
    }

    private var compactSavedResultsPanel: some View {
        CompactSavedResultsLibrary(
            model: historyModel,
            isOnLeadingSide: compactPanelIsLeading,
            onMoveToOtherSide: moveCompactPanel,
            onHide: { showsCompactSavedResults = false }
        )
        .frame(width: 244)
        .transition(
            .move(edge: compactPanelIsLeading ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    private var inspectionMain: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !showsCompactSavedResults {
                HStack {
                    if !compactPanelIsLeading {
                        Spacer()
                    }
                    Button {
                        showsCompactSavedResults = true
                    } label: {
                        Label(
                            "Show saved results",
                            systemImage:
                                compactPanelIsLeading
                                    ? "sidebar.left"
                                    : "sidebar.right"
                        )
                    }
                    .buttonStyle(SessionActionButtonStyle())
                    .help(
                        "Show the concise Saved Results panel on the \(compactPanelIsLeading ? "left" : "right")"
                    )
                    if compactPanelIsLeading {
                        Spacer()
                    }
                }
                .transition(.opacity)
            }

            historicalPresentation
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .layoutPriority(1)
    }

    @ViewBuilder
    private var historicalPresentation: some View {
        if let comparison = historyModel.comparison {
            HistoryComparisonPanel(
                comparison: comparison,
                onClose: historyModel.closePresentation
            )
        } else if let test = historyModel.openedTest {
            ResultPanel(
                result: test,
                onClose: historyModel.closePresentation
            )
        } else if let result = historyModel.openedResult {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    result.scope.title,
                    systemImage: "square.stack.3d.up"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                ResultPanel(
                    result: result.result,
                    onClose: historyModel.closePresentation
                )
            }
        }
    }

    private var canBrowseSavedResults: Bool {
        guard let status = model.engineState.session?.status else {
            return true
        }
        return [.completed, .cancelled].contains(status)
    }

    private var compactPanelIsLeading: Bool {
        savedResultsPanelSide == "left"
    }

    private func moveCompactPanel() {
        savedResultsPanelSide = compactPanelIsLeading ? "right" : "left"
    }
}

private struct TestsWorkspaceSwitcher: View {
    let showsSavedResults: Bool
    let canBrowseSavedResults: Bool
    let showNewTest: () -> Void
    let showSavedResults: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.workspaceInteractionSuppressed)
    private var workspaceInteractionSuppressed
    @State private var hoveredWorkspace: String?

    var body: some View {
        HStack(spacing: 4) {
            workspaceButton(
                title: "New test",
                systemImage: "plus",
                isSelected: !showsSavedResults,
                action: showNewTest
            )

            workspaceButton(
                title: "Saved results",
                systemImage: "clock.arrow.circlepath",
                isSelected: showsSavedResults,
                action: showSavedResults
            )
            .disabled(!canBrowseSavedResults)
            .help(
                canBrowseSavedResults
                    ? "Browse and compare completed controlled tests"
                    : "Saved Results is available before and after the active test"
            )
        }
        .padding(4)
        .background(
            Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.032),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(
                        colorSchemeContrast == .increased
                            ? (colorScheme == .dark ? 0.30 : 0.20)
                            : (colorScheme == .dark ? 0.15 : 0.075)
                    ),
                    lineWidth: 0.75
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tests workspace")
    }

    private func workspaceButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .background(
            Color.primary.opacity(
                isSelected ? 0.085 : (hoveredWorkspace == title ? 0.04 : 0)
            ),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(
                        isSelected
                            ? 0.14
                            : (hoveredWorkspace == title ? 0.075 : 0)
                    ),
                    lineWidth: 0.75
                )
        }
        .onHover { isHovering in
            hoveredWorkspace =
                isHovering && !workspaceInteractionSuppressed ? title : nil
        }
        .animation(.easeOut(duration: 0.1), value: hoveredWorkspace)
        .onChange(of: workspaceInteractionSuppressed) { _, suppressed in
            if suppressed {
                hoveredWorkspace = nil
            }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SetupPanel: View {
    @ObservedObject var model: SessionsViewModel
    @Binding var showsAdvanced: Bool

    private let durationOptions: [TimeInterval] = [10, 30, 60, 120, 300]
    private let warmUpOptions: [TimeInterval] = [0, 3, 5, 10]

    var body: some View {
        SessionSurface {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Set up a controlled test")
                            .font(.system(size: 21, weight: .semibold))
                        Text("Choose the applications first, then decide how Observatory should test them.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SessionEyebrow(
                        title: "METRICS ONLY",
                        color: EditorialPalette.blue
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SetupStepLabel(
                            number: "1",
                            title: "Choose applications",
                            detail: "Select up to four running apps."
                        )
                        Spacer()
                        Text("\(model.selectedApplications.count) of 4 selected")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button(action: model.refreshApplications) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(SessionIconButtonStyle())
                        .focusable()
                        .help("Refresh running applications")
                        .accessibilityLabel("Refresh running applications")
                    }

                    if model.runningApplications.isEmpty {
                        Text("No running applications are available.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 180), spacing: 6)
                            ],
                            alignment: .leading,
                            spacing: 6
                        ) {
                            ForEach(model.runningApplications) { application in
                                ApplicationSelectionButton(
                                    application: application,
                                    isSelected: model.selectedApplications.contains(
                                        application.identity
                                    ),
                                    action: {
                                        model.toggleApplication(application)
                                    }
                                )
                            }
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    SetupStepLabel(
                        number: "2",
                        title: "Configure the run",
                        detail: "Choose who drives the test and how long each round lasts."
                    )

                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Method")
                                .sessionFieldLabel()

                            HStack(spacing: 4) {
                                TestModeButton(
                                    title: "Manual guided",
                                    systemImage: "hand.tap",
                                    isSelected:
                                        model.controlledTestMode == .manualGuided
                                ) {
                                    model.controlledTestMode = .manualGuided
                                }
                                TestModeButton(
                                    title: "Foreground idle",
                                    systemImage: "arrow.triangle.2.circlepath",
                                    isSelected:
                                        model.controlledTestMode
                                        == .automaticForegroundIdle
                                ) {
                                    model.controlledTestMode =
                                        .automaticForegroundIdle
                                }
                            }
                            .padding(4)
                            .background(
                                Color.primary.opacity(0.025),
                                in: RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    Color.primary.opacity(0.065),
                                    lineWidth: 0.75
                                )
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Controlled test method")

                            Text(modeDetail)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .contentTransition(.opacity)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Test name")
                                .sessionFieldLabel()
                            TextField(
                                "Defaults to the selected application names",
                                text: $model.sessionName
                            )
                            .textFieldStyle(.plain)
                            .sessionTextField()
                            .accessibilityLabel("Controlled test name")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Measured time")
                            .sessionFieldLabel()
                        HStack(spacing: 4) {
                            ForEach(durationOptions, id: \.self) { duration in
                                SessionChoiceButton(
                                    title: durationCompactLabel(duration),
                                    isSelected: model.measuredDuration == duration
                                ) {
                                    model.measuredDuration = duration
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rounds")
                            .sessionFieldLabel()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { count in
                                SessionChoiceButton(
                                    title: "\(count)",
                                    isSelected: model.roundCount == count,
                                    compact: true
                                ) {
                                    model.roundCount = count
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(startSummary)
                            .font(.system(size: 12, weight: .medium))
                        Text(startDetail)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(
                        model.controlledTestMode == .manualGuided
                            ? "Start test"
                            : "Start idle test",
                        action: model.createSession
                    )
                    .buttonStyle(SessionActionButtonStyle(primary: true))
                    .focusable()
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        model.selectedApplications.isEmpty || model.isWorking
                    )
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeOut(duration: 0.14)) {
                            showsAdvanced.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Advanced controls")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(showsAdvanced ? 180 : 0))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .accessibilityLabel("Advanced test controls")
                    .accessibilityValue(showsAdvanced ? "Expanded" : "Collapsed")

                    if showsAdvanced {
                        Divider()
                            .padding(.bottom, 14)

                        advancedControls
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 12)
                .background(
                    Color.primary.opacity(0.025),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
                }
            }
        }
    }

    private var modeDetail: String {
        switch model.controlledTestMode {
        case .manualGuided:
            "You bring each app forward and repeat the workload."
        case .automaticForegroundIdle:
            "Observatory brings each app forward for an equal idle interval."
        }
    }

    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Workload note")
                    .sessionFieldLabel()
                TextField(
                    "Describe the action you will repeat",
                    text: $model.note,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .sessionTextField(minHeight: 48)
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warm-up")
                        .sessionFieldLabel()
                    HStack(spacing: 4) {
                        ForEach(warmUpOptions, id: \.self) { duration in
                            SessionChoiceButton(
                                title: duration == 0 ? "None" : "\(Int(duration))s",
                                isSelected: model.warmUpDuration == duration,
                                compact: true
                            ) {
                                model.warmUpDuration = duration
                            }
                        }
                    }
                }

                if model.controlledTestMode == .manualGuided {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Global shortcut")
                            .sessionFieldLabel()
                        HStack(spacing: 4) {
                            SessionChoiceButton(
                                title: "None",
                                isSelected: model.shortcut == .none
                            ) {
                                model.shortcut = .none
                            }
                            SessionChoiceButton(
                                title: "⌘⌥ Space",
                                isSelected:
                                    model.shortcut == .commandOptionSpace
                            ) {
                                model.shortcut = .commandOptionSpace
                            }
                            SessionChoiceButton(
                                title: "⌃⌥ Return",
                                isSelected:
                                    model.shortcut == .controlOptionReturn
                            ) {
                                model.shortcut = .controlOptionReturn
                            }
                        }
                    }
                }
            }

            Text(
                model.controlledTestMode == .manualGuided
                    ? "The compact prompt always remains clickable. The shortcut only applies while this test is active."
                    : "Automatic mode uses normal macOS app activation and never simulates input or requires Accessibility permission."
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 14)
    }

    private var startSummary: String {
        guard !model.selectedApplications.isEmpty else {
            return "Choose at least one application"
        }
        let count = model.selectedApplications.count
        return "\(count) \(count == 1 ? "application" : "applications") · \(model.roundCount) \(model.roundCount == 1 ? "round" : "rounds")"
    }

    private var startDetail: String {
        guard !model.selectedApplications.isEmpty else {
            return "You can compare up to four applications in one test."
        }
        let seconds =
            (model.measuredDuration + model.warmUpDuration)
            * Double(model.roundCount)
            * Double(model.selectedApplications.count)
        if model.warmUpDuration == 0 {
            return "About \(durationLabel(seconds)) total · no warm-up"
        }
        return "About \(durationLabel(seconds)) including warm-up"
    }

    private func durationCompactLabel(_ duration: TimeInterval) -> String {
        duration < 60 ? "\(Int(duration))s" : "\(Int(duration / 60))m"
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration)) seconds"
        }
        let minutes = Int(ceil(duration / 60))
        return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
    }
}

private struct SetupStepLabel: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 9) {
            Text(number)
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.075), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TestModeButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .symbolEffect(
                        .bounce,
                        options: reduceMotion ? .nonRepeating : .default,
                        value: isSelected
                    )
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(
                        isSelected ? Color.primary : Color.secondary
                    )
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.6)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .background(
            Color.primary.opacity(
                isSelected ? 0.085 : (isHovering ? 0.045 : 0)
            ),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(
                        isSelected ? 0.16 : (isHovering ? 0.09 : 0)
                    ),
                    lineWidth: 0.75
                )
        }
        .workspaceHover($isHovering)
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.08)
                : .spring(response: 0.24, dampingFraction: 0.72),
            value: isSelected
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SessionChoiceButton: View {
    let title: String
    let isSelected: Bool
    var compact = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(minWidth: compact ? 28 : 42, minHeight: 28)
                .padding(.horizontal, compact ? 3 : 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .background(
            Color.primary.opacity(
                isSelected ? 0.085 : (isHovering ? 0.045 : 0.025)
            ),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(
                        isSelected ? 0.2 : (isHovering ? 0.11 : 0.065)
                    ),
                    lineWidth: 0.75
                )
        }
        .workspaceHover($isHovering)
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SessionEyebrow: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.55)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }
}

struct SessionActionButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(primary ? primaryForeground : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(
                primary
                    ? Color.primary.opacity(
                        configuration.isPressed ? 0.78 : (isHovering ? 1 : 0.9)
                    )
                    : Color.primary.opacity(
                        configuration.isPressed ? 0.09 : (isHovering ? 0.07 : 0.045)
                    ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(primary ? 0.12 : 0.085),
                        lineWidth: 0.75
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.38)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.1), value: isHovering)
            .workspaceHover($isHovering)
    }

    private var primaryForeground: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.105)
            : Color.white
    }
}

struct SessionIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .frame(width: 30, height: 30)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.09 : 0.035),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
            }
    }
}

struct SessionRowButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background(
                Color.primary.opacity(
                    configuration.isPressed ? 0.07 : (isHovering ? 0.035 : 0)
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .workspaceHover($isHovering)
            .animation(.easeOut(duration: 0.1), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct ApplicationSelectionButton: View {
    let application: SessionApplication
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var showsVersion = false

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .focusable()
        .onKeyPress(keys: [.return, .space]) { _ in
            action()
            return .handled
        }
        .background(
            backgroundColor,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(
                        isSelected ? 0.24 : (isHovering ? 0.12 : 0.07)
                    ),
                    lineWidth: isSelected ? 1 : 0.75
                )
        }
        .overlay(alignment: .topTrailing) {
            if showsVersion {
                versionLabel
                    .offset(x: -6, y: -18)
            }
        }
        .workspaceHover($isHovering)
        .zIndex(showsVersion ? 1 : 0)
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .accessibilityLabel(application.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(versionHelp)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var label: some View {
        HStack(spacing: 10) {
            Image(nsImage: applicationIcon)
                .resizable()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            Text(application.displayName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }

            Spacer()

            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(
                    showsVersion
                        ? Color.secondary
                        : Color.secondary.opacity(0.7)
                )
                .frame(width: 24, height: 30)
                .contentShape(Rectangle())
                .workspaceHover($showsVersion)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private var applicationIcon: NSImage {
        NSWorkspace.shared.icon(forFile: application.identity.bundleURL.path)
    }

    private var versionHelp: String {
        application.version.map { "Version \($0)" }
            ?? "Version unavailable"
    }

    private var versionLabel: some View {
        Text(versionHelp)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                versionLabelBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(0.14),
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color: Color.black.opacity(0.12),
                radius: 5,
                y: 2
            )
            .allowsHitTesting(false)
    }

    private var backgroundColor: Color {
        Color.primary.opacity(
            isSelected ? 0.065 : (isHovering ? 0.04 : 0.02)
        )
    }

    private var versionLabelBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.123, blue: 0.119)
            : Color(red: 0.986, green: 0.982, blue: 0.973)
    }
}

private struct ActiveTestPanel: View {
    let state: ControlledTestEngineState
    let isWorking: Bool
    let onBegin: () -> Void
    let onSkip: () -> Void
    let onRetry: (SessionRound) -> Void
    let onFinishPartial: () -> Void
    let onCancel: () -> Void

    var body: some View {
        SessionSurface {
            VStack(alignment: .leading, spacing: 22) {
                if let session = state.session {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.name)
                                .font(.system(size: 22, weight: .bold, design: .serif))
                            Text(sessionStatus(session))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Label(
                            session.controlledTestMode == .automaticForegroundIdle
                                ? "Foreground idle"
                                : "Manual guided",
                            systemImage: session.controlledTestMode
                                == .automaticForegroundIdle
                                ? "arrow.triangle.2.circlepath"
                                : "record.circle"
                        )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if let round = state.currentRound {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(round.application.displayName)
                                    .font(.system(size: 19, weight: .semibold))
                                Text(
                                    "Round \(round.roundNumber) · target \(round.sequenceNumber) of \(state.rounds.count)"
                                )
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            RoundStatusLabel(status: round.status)
                        }

                        if [.warmingUp, .recording].contains(round.status),
                           let remaining = state.remainingDuration,
                           let configuration = state.session?
                            .controlledTestConfiguration {
                            ProgressView(
                                value: max(
                                    0,
                                    configuration.warmUpDuration
                                        + configuration.measuredDuration
                                        - remaining
                                ),
                                total: configuration.warmUpDuration
                                    + configuration.measuredDuration
                            )
                            Text("\(Int(ceil(remaining))) seconds remaining")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else if state.session?.controlledTestMode == .manualGuided {
                            Text(
                                "Bring \(round.application.displayName) to the foreground, prepare the workload, then begin from Observatory or the compact prompt."
                            )
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)

                            HStack(spacing: 8) {
                                Button("Begin round", action: onBegin)
                                    .buttonStyle(
                                        SessionActionButtonStyle(primary: true)
                                    )
                                    .focusable()
                                    .keyboardShortcut(.defaultAction)
                                Button("Skip application", action: onSkip)
                                    .buttonStyle(SessionActionButtonStyle())
                                    .focusable()
                            }
                            .disabled(isWorking)
                        } else if round.status == .activating {
                            Label(
                                "Requesting foreground access and waiting for macOS confirmation. Activation is retried up to three times.",
                                systemImage: "macwindow.on.rectangle"
                            )
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        } else {
                            Text(
                                "Observatory will continue this foreground-idle sequence automatically."
                            )
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rounds")
                        .font(.system(size: 14, weight: .semibold))
                    ForEach(state.rounds) { round in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 10) {
                                Text("\(round.sequenceNumber)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(round.application.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                Text("Round \(round.roundNumber)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                RoundStatusLabel(status: round.status)
                                if state.session?.controlledTestMode == .manualGuided,
                                   [.completed, .interrupted, .skipped]
                                    .contains(round.status) {
                                    Button("Retry") { onRetry(round) }
                                        .buttonStyle(.plain)
                                        .focusable()
                                        .font(.system(size: 11, weight: .medium))
                                        .disabled(isWorking)
                                }
                            }
                            if round.status == .failed,
                               let reason = round.interruptionReason {
                                Text(reason)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                                    .padding(.leading, 30)
                            }
                        }
                        .frame(minHeight: 28)
                    }
                }

                HStack {
                    Button("Cancel test", role: .destructive, action: onCancel)
                        .buttonStyle(.plain)
                        .focusable()
                        .foregroundStyle(.red)
                    Spacer()
                    if state.rounds.contains(where: { $0.status == .completed }),
                       state.rounds.contains(where: { $0.status == .pending }) {
                        Button("Finish with partial results", action: onFinishPartial)
                            .buttonStyle(SessionActionButtonStyle())
                            .focusable()
                            .disabled(isWorking)
                    }
                }
            }
        }
    }

    private func sessionStatus(_ session: MonitoringSession) -> String {
        switch session.status {
        case .planned, .paused:
            session.controlledTestMode == .automaticForegroundIdle
                ? "Preparing the next foreground-idle round"
                : "Waiting for the next guided round"
        case .activating:
            "Requesting activation and confirming the foreground application"
        case .warmingUp:
            "Warm-up data is being recorded but will not be scored"
        case .recording:
            "Measured interval in progress"
        case .completed:
            "Completed"
        case .cancelled:
            "Cancelled with partial results"
        case .failed:
            "Paused after a failure"
        }
    }
}

private struct RecoveryPanel: View {
    let state: ControlledTestEngineState
    let onContinue: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        SessionSurface {
            VStack(alignment: .leading, spacing: 16) {
                Label("Unfinished controlled test", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 20, weight: .semibold))
                Text(
                    "“\(state.session?.name ?? "Untitled test")” stopped before it finished. Recorded samples and completed rounds are intact."
                )
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                HStack(spacing: 8) {
                    Button("Continue test", action: onContinue)
                        .buttonStyle(SessionActionButtonStyle(primary: true))
                        .focusable()
                        .keyboardShortcut(.defaultAction)
                    Button("Discard test", role: .destructive, action: onDiscard)
                        .buttonStyle(SessionActionButtonStyle())
                        .focusable()
                }
            }
        }
    }
}

struct ResultPanel: View {
    let result: ControlledTestResult
    let onClose: () -> Void

    var body: some View {
        SessionSurface {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.session.name)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                        Text(resultContext)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(macOSVersionLabel(result.session.systemVersion))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Done", action: onClose)
                        .buttonStyle(SessionActionButtonStyle())
                        .focusable()
                        .keyboardShortcut(.cancelAction)
                }

                if !result.session.note.isEmpty {
                    Label(result.session.note, systemImage: "note.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if result.summaries.isEmpty {
                    Text("No measured round was completed.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 24)
                } else {
                    LazyVGrid(
                        columns: result.summaries.count == 1
                            ? [GridItem(.flexible())]
                            : [GridItem(.adaptive(minimum: 280), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(result.summaries) { summary in
                            ResultSummaryCard(summary: summary)
                        }
                    }
                }

                ResultTimelinePanel(result: result)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Round record")
                        .font(.system(size: 14, weight: .semibold))
                    ForEach(result.rounds) { round in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(round.application.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                Text("Round \(round.roundNumber)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                RoundStatusLabel(status: round.status)
                            }
                            if round.status == .failed,
                               let reason = round.interruptionReason {
                                Text(reason)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }

    private var resultContext: String {
        let duration = result.session.controlledTestConfiguration?.measuredDuration ?? 0
        let mode = result.session.controlledTestMode == .automaticForegroundIdle
            ? "Foreground idle"
            : "Manual guided"
        return "\(mode) · \(Int(duration)) sec measured rounds · \(result.session.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct ResultSummaryCard: View {
    let summary: ApplicationResultSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.application.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text(
                        summary.application.version.map { "App version \($0)" }
                            ?? "App version unknown"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(summary.completedRoundCount) \(summary.completedRoundCount == 1 ? "round" : "rounds")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 130), alignment: .leading)
                ],
                spacing: 12
            ) {
                ResultMetric(
                    label: "Average CPU",
                    value: summary.averageCPUCoreUsage.map {
                        String(format: "%.1f%%", $0 * 100)
                    } ?? "Unavailable"
                )
                ResultMetric(
                    label: "Peak CPU",
                    value: summary.peakCPUCoreUsage.map {
                        String(format: "%.1f%%", $0 * 100)
                    } ?? "Unavailable"
                )
                ResultMetric(
                    label: "Peak memory",
                    value: bytes(summary.peakMemoryBytes.map { Double($0) })
                )
                ResultMetric(
                    label: "Disk written",
                    value: bytes(summary.diskWriteBytes)
                )
                ResultMetric(
                    label: "Wakeups",
                    value: summary.averageWakeupsPerSecond.map {
                        String(format: "%.1f/sec avg", $0)
                    } ?? "Unavailable"
                )
                ResultMetric(
                    label: "Samples",
                    value: "\(summary.sampleCount) measured"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func bytes(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return ByteCountFormatter.string(
            fromByteCount: Int64(min(value, Double(Int64.max))),
            countStyle: .memory
        )
    }
}

private struct ResultMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private enum TimelineScaleMode: String, CaseIterable, Identifiable {
    case shared
    case independent

    var id: Self { self }
}

private struct TimelineScaleShelf: View {
    @Binding var scaleMode: TimelineScaleMode

    var body: some View {
        HStack(spacing: 4) {
            SessionChoiceButton(
                title: "Shared",
                isSelected: scaleMode == .shared
            ) {
                scaleMode = .shared
            }
            SessionChoiceButton(
                title: "Independent",
                isSelected: scaleMode == .independent
            ) {
                scaleMode = .independent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vertical chart scale")
    }
}

struct TimelineMetricShelf: View {
    @Binding var metric: ResultTimelineMetric

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ResultTimelineMetric.allCases) { option in
                SessionChoiceButton(
                    title: option.shortTitle,
                    isSelected: metric == option
                ) {
                    metric = option
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline metric")
    }
}

struct SessionToggleButton: View {
    let title: String
    @Binding var isOn: Bool
    @State private var isHovering = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isOn ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .background(
            Color.primary.opacity(
                isOn ? 0.075 : (isHovering ? 0.045 : 0.025)
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(isOn ? 0.18 : 0.07),
                    lineWidth: 0.75
                )
        }
        .workspaceHover($isHovering)
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct ResultTimelinePanel: View {
    let timeline: ResultTimeline

    @State private var metric = ResultTimelineMetric.cpu
    @State private var scaleMode = TimelineScaleMode.shared
    @State private var selectedElapsed: TimeInterval = 0

    init(result: ControlledTestResult) {
        let timeline = ResultTimeline(result: result)
        self.timeline = timeline
        _selectedElapsed = State(
            initialValue: timeline.samples.first {
                !$0.sample.isWarmUp
            }?.elapsed ?? timeline.elapsedDomain.lowerBound
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metric timeline")
                        .font(.system(size: 17, weight: .semibold))
                    Text(
                        "Measured elapsed time is aligned across applications and rounds."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                TimelineScaleShelf(scaleMode: $scaleMode)
                .help(
                    scaleMode == .shared
                        ? "Every application uses the same vertical scale."
                        : "Each application uses its own vertical scale."
                )
            }

            TimelineMetricShelf(metric: $metric)

            if timeline.samples.isEmpty {
                Label(
                    "No stored metric samples are available for this result.",
                    systemImage: "chart.xyaxis.line"
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                timelineLegend

                LazyVGrid(
                    columns: chartColumns,
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(
                        Array(timeline.applications.enumerated()),
                        id: \.element.identity
                    ) { index, application in
                        ResultMetricChart(
                            timeline: timeline,
                            application: application,
                            metric: metric,
                            seriesColor: seriesColor(index),
                            xDomain: timeline.elapsedDomain,
                            yDomain: yDomain(for: application),
                            selectedElapsed: $selectedElapsed
                        )
                    }
                }

                TimelineInspector(
                    elapsed: selectedElapsed,
                    samples: timeline.nearestSamples(to: selectedElapsed)
                )
            }
        }
        .padding(.top, 2)
    }

    private var chartColumns: [GridItem] {
        timeline.applications.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 320), spacing: 12)]
    }

    private var timelineLegend: some View {
        HStack(spacing: 16) {
            Label("Warm-up trace", systemImage: "clock")
            Label("Foreground points", systemImage: "circle.fill")
            Label("Partial sample", systemImage: "diamond")
            if unavailableSampleCount > 0 {
                Label(
                    "\(unavailableSampleCount) unavailable",
                    systemImage: "chart.line.downtrend.xyaxis"
                )
            }
            Spacer()
            if metric == .disk {
                HStack(spacing: 10) {
                    Label("Read", systemImage: "circle.fill")
                    Label("Write", systemImage: "square.fill")
                }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
    }

    private var unavailableSampleCount: Int {
        timeline.samples.reduce(into: 0) { count, sample in
            let isUnavailable: Bool
            if metric == .disk {
                isUnavailable =
                    sample.value(for: metric, component: .diskRead) == nil
                    && sample.value(for: metric, component: .diskWrite) == nil
            } else {
                isUnavailable = sample.value(for: metric) == nil
            }
            if isUnavailable {
                count += 1
            }
        }
    }

    private func yDomain(
        for application: SessionApplication
    ) -> ClosedRange<Double> {
        let applications =
            scaleMode == .shared ? timeline.applications : [application]
        let maximum = applications
            .flatMap { timeline.points(for: $0.identity, metric: metric) }
            .map(\.value)
            .max() ?? 0
        let paddedMaximum = maximum > 0 ? maximum * 1.08 : 1
        return 0...paddedMaximum
    }

    private func seriesColor(_ index: Int) -> Color {
        let colors = [
            Color(red: 0.17, green: 0.69, blue: 0.78),
            Color(red: 0.58, green: 0.47, blue: 0.82),
            Color(red: 0.25, green: 0.70, blue: 0.55),
            Color(red: 0.91, green: 0.43, blue: 0.36)
        ]
        return colors[index % colors.count]
    }
}

struct HistoryComparisonTimelinePanel: View {
    let results: [HistoricalApplicationResult]

    @State private var metric = ResultTimelineMetric.cpu
    @State private var scaleMode = TimelineScaleMode.shared
    @State private var selectedElapsed: TimeInterval = 0
    @State private var showsWarmUp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metric timelines")
                        .font(.system(size: 17, weight: .semibold))
                    Text(
                        "Every result uses the same elapsed-time domain. Shorter recordings end at their last raw sample."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                SessionToggleButton(
                    title: "Warm-up",
                    isOn: $showsWarmUp
                )
                TimelineScaleShelf(scaleMode: $scaleMode)
            }

            TimelineMetricShelf(metric: $metric)
                .accessibilityLabel("Comparison metric")

            comparisonLegend

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 320), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(Array(timelines.enumerated()), id: \.element.result.id) {
                    index, entry in
                    ResultMetricChart(
                        timeline: entry.timeline,
                        application: entry.result.application,
                        metric: metric,
                        seriesColor: historySeriesColor(index),
                        xDomain: elapsedDomain,
                        yDomain: yDomain(for: entry),
                        selectedElapsed: $selectedElapsed
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(timelines, id: \.result.id) { entry in
                    TimelineInspector(
                        elapsed: selectedElapsed,
                        samples: entry.timeline.nearestSamples(to: selectedElapsed)
                    )
                }
            }
        }
        .onChange(of: showsWarmUp) {
            selectedElapsed = min(
                elapsedDomain.upperBound,
                max(elapsedDomain.lowerBound, selectedElapsed)
            )
        }
    }

    private var timelines: [ComparisonTimelineEntry] {
        results.map { result in
            let samples = showsWarmUp
                ? result.result.samples
                : result.result.samples.filter { !$0.isWarmUp }
            let filteredResult = ControlledTestResult(
                session: result.result.session,
                rounds: result.result.rounds,
                samples: samples,
                summaries: result.result.summaries
            )
            return ComparisonTimelineEntry(
                result: result,
                timeline: ResultTimeline(result: filteredResult)
            )
        }
    }

    private var elapsedDomain: ClosedRange<TimeInterval> {
        let samples = timelines.flatMap(\.timeline.samples)
        guard let minimum = samples.map(\.elapsed).min(),
              let maximum = samples.map(\.elapsed).max() else {
            return 0...1
        }
        if minimum == maximum {
            return minimum...(maximum + 1)
        }
        return minimum...maximum
    }

    private var comparisonLegend: some View {
        HStack(spacing: 16) {
            Label("Foreground points", systemImage: "circle.fill")
            Label("Partial sample", systemImage: "diamond")
            if unavailableSampleCount > 0 {
                Label(
                    "\(unavailableSampleCount) unavailable",
                    systemImage: "chart.line.downtrend.xyaxis"
                )
            }
            if showsWarmUp {
                Label("Warm-up trace", systemImage: "clock")
            }
            Spacer()
            if metric == .disk {
                Label("Read / write", systemImage: "circle.square")
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private var unavailableSampleCount: Int {
        timelines.flatMap(\.timeline.samples).reduce(into: 0) { count, sample in
            let unavailable =
                metric == .disk
                    ? (
                        sample.value(for: metric, component: .diskRead) == nil
                            && sample.value(for: metric, component: .diskWrite)
                                == nil
                    )
                    : sample.value(for: metric) == nil
            if unavailable {
                count += 1
            }
        }
    }

    private func yDomain(
        for entry: ComparisonTimelineEntry
    ) -> ClosedRange<Double> {
        let candidates =
            scaleMode == .shared ? timelines : [entry]
        let maximum = candidates
            .flatMap {
                $0.timeline.points(
                    for: $0.result.application.identity,
                    metric: metric
                )
            }
            .map(\.value)
            .max() ?? 0
        return 0...(maximum > 0 ? maximum * 1.08 : 1)
    }

    private struct ComparisonTimelineEntry {
        let result: HistoricalApplicationResult
        let timeline: ResultTimeline
    }
}

private struct ResultMetricChart: View {
    let timeline: ResultTimeline
    let application: SessionApplication
    let metric: ResultTimelineMetric
    let seriesColor: Color
    let xDomain: ClosedRange<TimeInterval>
    let yDomain: ClosedRange<Double>
    @Binding var selectedElapsed: TimeInterval

    private var samples: [ResultTimelineSample] {
        timeline.samples(for: application.identity)
    }

    private var points: [ResultTimelinePoint] {
        timeline.points(for: application.identity, metric: metric)
    }

    private var selectedSamples: [ResultTimelineSample] {
        timeline.nearestSamples(to: selectedElapsed).filter {
            $0.application.identity == application.identity
        }
    }

    private var warmUpTransitionPoints: [ResultTimelinePoint] {
        let grouped = Dictionary(grouping: points) {
            "\($0.sample.round.id.uuidString)-\($0.component.rawValue)"
        }
        return grouped.values.flatMap { candidates in
            let ordered = candidates.sorted {
                $0.sample.elapsed < $1.sample.elapsed
            }
            guard let warmUp = ordered.last(where: {
                $0.sample.sample.isWarmUp
            }),
                  let measured = ordered.first(where: {
                      !$0.sample.sample.isWarmUp
                  }),
                  measured.segment == warmUp.segment + 1 else {
                return [ResultTimelinePoint]()
            }
            return [warmUp, measured]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(chartSubtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(seriesColor)
                    .frame(width: 8, height: 8)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                    }
                    .accessibilityHidden(true)
            }

            roundLegend

            Chart {
                if xDomain.lowerBound < 0 {
                    RuleMark(x: .value("Measured time begins", 0))
                        .foregroundStyle(Color.primary.opacity(0.1))
                }

                ForEach(warmUpTransitionPoints) { point in
                    LineMark(
                        x: .value(
                            "Warm-up transition time",
                            point.sample.elapsed
                        ),
                        y: .value(metric.title, point.value),
                        series: .value(
                            "Warm-up transition",
                            transitionIdentifier(point)
                        )
                    )
                    .foregroundStyle(seriesColor.opacity(0.82))
                    .lineStyle(
                        timelineStrokeStyle(
                            roundNumber: point.sample.round.roundNumber,
                            isWarmUp: false
                        )
                    )
                    .accessibilityHidden(true)
                }

                ForEach(points) { point in
                    LineMark(
                        x: .value("Elapsed time", point.sample.elapsed),
                        y: .value(metric.title, point.value),
                        series: .value("Series", seriesIdentifier(point))
                    )
                    .foregroundStyle(
                        seriesColor.opacity(
                            point.sample.sample.isPartial ? 0.62 : 1
                        )
                    )
                    .lineStyle(strokeStyle(for: point))

                    PointMark(
                        x: .value("Elapsed time", point.sample.elapsed),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(
                        seriesColor.opacity(
                            point.sample.sample.state == .frontmost ? 0.92 : 0.48
                        )
                    )
                    .symbol(symbol(for: point))
                    .symbolSize(
                        point.sample.sample.isPartial
                            ? 18
                            : (
                                point.sample.sample.state == .frontmost
                                    ? 10
                                    : 6
                            )
                    )
                }

                ForEach(selectedSamples) { sample in
                    RuleMark(
                        x: .value("Selected sample time", sample.elapsed)
                    )
                    .foregroundStyle(seriesColor.opacity(0.46))
                    .lineStyle(
                        StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                    .annotation(
                        position: .bottom,
                        alignment: .center,
                        spacing: 4
                    ) {
                        TimelineGuideLabel(
                            text: elapsedLabel(sample.elapsed),
                            color: seriesColor
                        )
                    }

                    ForEach(selectedComponents(for: sample), id: \.component) {
                        selected in
                        RuleMark(
                            y: .value(
                                "Selected sample value",
                                selected.value
                            )
                        )
                        .foregroundStyle(seriesColor.opacity(0.46))
                        .lineStyle(
                            StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .annotation(
                            position: .leading,
                            alignment: .center,
                            spacing: 4
                        ) {
                            TimelineGuideLabel(
                                text: metric.guideLabel(
                                    selected.value,
                                    component: selected.component
                                ),
                                color: seriesColor
                            )
                        }

                        PointMark(
                            x: .value("Selected elapsed time", sample.elapsed),
                            y: .value(metric.title, selected.value)
                        )
                        .foregroundStyle(seriesColor)
                        .symbol(
                            selected.component == .diskWrite ? .square : .circle
                        )
                        .symbolSize(54)
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.primary.opacity(0.045))
                    AxisTick()
                        .foregroundStyle(Color.primary.opacity(0.12))
                    AxisValueLabel {
                        if let elapsed = value.as(Double.self) {
                            Text(elapsedLabel(elapsed))
                        }
                    }
                    .font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) {
                    value in
                    AxisGridLine()
                        .foregroundStyle(Color.primary.opacity(0.055))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(metric.axisLabel(number))
                        }
                    }
                    .font(.system(size: 9))
                }
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            if case .active(let location) = phase {
                                updateSelection(
                                    at: location,
                                    proxy: proxy,
                                    geometry: geometry
                                )
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    updateSelection(
                                        at: gesture.location,
                                        proxy: proxy,
                                        geometry: geometry
                                    )
                                }
                        )
                }
            }
            .frame(height: 220)
            .accessibilityLabel(
                "\(application.displayName), \(metric.title) timeline"
            )
            .accessibilityValue(
                "Cursor at \(elapsedLabel(selectedElapsed))"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            Color.primary.opacity(0.032),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
        }
    }

    private var chartSubtitle: String {
        let roundCount = Set(samples.map(\.round.id)).count
        return "\(metric.title) · \(roundCount) \(roundCount == 1 ? "round" : "rounds")"
    }

    @ViewBuilder
    private var roundLegend: some View {
        let roundNumbers = Array(Set(samples.map(\.round.roundNumber))).sorted()
        if roundNumbers.count > 1 {
            HStack(spacing: 12) {
                ForEach(roundNumbers, id: \.self) { roundNumber in
                    HStack(spacing: 5) {
                        TimelineLegendLine(
                            style: timelineStrokeStyle(
                                roundNumber: roundNumber,
                                isWarmUp: false
                            ),
                            color: seriesColor
                        )
                        .frame(width: 24, height: 6)
                        Text("Round \(roundNumber)")
                    }
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
    }

    private func selectedComponents(
        for sample: ResultTimelineSample
    ) -> [(component: ResultTimelineComponent, value: Double)] {
        let components: [ResultTimelineComponent] =
            metric == .disk ? [.diskRead, .diskWrite] : [.primary]
        return components.compactMap { component in
            sample.value(for: metric, component: component).map {
                (component, $0)
            }
        }
    }

    private func seriesIdentifier(_ point: ResultTimelinePoint) -> String {
        "\(point.sample.round.id.uuidString)-\(point.component.rawValue)-\(point.segment)"
    }

    private func transitionIdentifier(
        _ point: ResultTimelinePoint
    ) -> String {
        "\(point.sample.round.id.uuidString)-\(point.component.rawValue)-warm-up-transition"
    }

    private func strokeStyle(for point: ResultTimelinePoint) -> StrokeStyle {
        timelineStrokeStyle(
            roundNumber: point.sample.round.roundNumber,
            isWarmUp: point.sample.sample.isWarmUp
        )
    }

    private func symbol(
        for point: ResultTimelinePoint
    ) -> BasicChartSymbolShape {
        if point.sample.sample.isPartial {
            return .diamond
        }
        return point.component == .diskWrite ? .square : .circle
    }

    private func updateSelection(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let plotX = location.x - frame.origin.x
        guard plotX >= 0,
              plotX <= frame.width,
              let elapsed: Double = proxy.value(atX: plotX) else {
            return
        }
        selectedElapsed = min(
            xDomain.upperBound,
            max(xDomain.lowerBound, elapsed)
        )
    }
}

private struct TimelineGuideLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .frame(height: 19)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.94),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(color.opacity(0.46), lineWidth: 0.75)
            }
            .accessibilityHidden(true)
    }
}

struct TimelineLegendLine: View {
    let style: StrokeStyle
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(
                    to: CGPoint(x: 0, y: geometry.size.height / 2)
                )
                path.addLine(
                    to: CGPoint(
                        x: geometry.size.width,
                        y: geometry.size.height / 2
                    )
                )
            }
            .stroke(color, style: style)
        }
    }
}

private struct TimelineInspector: View {
    let elapsed: TimeInterval
    let samples: [ResultTimelineSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Exact recorded sample", systemImage: "scope")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(elapsedLabel(elapsed))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }

            if samples.isEmpty {
                Text("No application has a recorded sample at this elapsed time.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 54)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(samples) { sample in
                            TimelineSampleCard(sample: sample)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(14)
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

private struct TimelineSampleCard: View {
    let sample: ResultTimelineSample

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sample.application.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    Text("Round \(sample.round.roundNumber)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(
                    "\(elapsedLabel(sample.elapsed)) · \(sample.sample.capturedAt.formatted(date: .omitted, time: .standard))"
                )
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ],
                alignment: .leading,
                spacing: 7
            ) {
                inspectorValue(
                    "CPU",
                    sample.value(for: .cpu).map {
                        String(format: "%.1f%%", $0)
                    }
                )
                inspectorValue(
                    "Memory",
                    sample.value(for: .memory).map(formatBytes)
                )
                inspectorValue(
                    "Disk read",
                    sample.value(for: .disk, component: .diskRead).map {
                        "\(formatBytes($0))/s"
                    }
                )
                inspectorValue(
                    "Disk write",
                    sample.value(for: .disk, component: .diskWrite).map {
                        "\(formatBytes($0))/s"
                    }
                )
                inspectorValue(
                    "Wakeups",
                    sample.value(for: .wakeups).map {
                        String(format: "%.1f/s", $0)
                    }
                )
                inspectorValue(
                    "Processes",
                    sample.value(for: .processCount).map {
                        String(Int($0))
                    }
                )
            }

            HStack(spacing: 5) {
                if sample.sample.isWarmUp {
                    sampleBadge("Warm-up", symbol: "clock")
                }
                if sample.sample.state == .frontmost {
                    sampleBadge("Foreground", symbol: "macwindow")
                }
                if sample.sample.isPartial {
                    sampleBadge("Partial", symbol: "diamond")
                }
            }
        }
        .padding(11)
        .frame(width: 250, alignment: .leading)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(sample.application.displayName), round \(sample.round.roundNumber)"
        )
        .accessibilityValue(accessibilityValue)
    }

    private func inspectorValue(
        _ label: String,
        _ value: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value ?? "Unavailable")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
    }

    private func sampleBadge(
        _ label: String,
        symbol: String
    ) -> some View {
        Label(label, systemImage: symbol)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }

    private var accessibilityValue: String {
        let values = [
            "elapsed \(elapsedLabel(sample.elapsed))",
            "clock \(sample.sample.capturedAt.formatted(date: .omitted, time: .standard))",
            "CPU \(sample.value(for: .cpu).map { String(format: "%.1f%%", $0) } ?? "unavailable")",
            "memory \(sample.value(for: .memory).map(formatBytes) ?? "unavailable")",
            "disk read \(sample.value(for: .disk, component: .diskRead).map { "\(formatBytes($0)) per second" } ?? "unavailable")",
            "disk write \(sample.value(for: .disk, component: .diskWrite).map { "\(formatBytes($0)) per second" } ?? "unavailable")",
            "wakeups \(sample.value(for: .wakeups).map { String(format: "%.1f per second", $0) } ?? "unavailable")",
            "processes \(sample.value(for: .processCount).map { String(Int($0)) } ?? "unavailable")"
        ]
        var states: [String] = []
        if sample.sample.isWarmUp {
            states.append("warm-up")
        }
        if sample.sample.state == .frontmost {
            states.append("foreground")
        }
        if sample.sample.isPartial {
            states.append("partial")
        }
        return (values + states).joined(separator: ", ")
    }
}

extension ResultTimelineMetric {
    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk I/O"
        case .wakeups: "Wakeups"
        case .processCount: "Process count"
        }
    }

    var shortTitle: String {
        switch self {
        case .processCount: "Processes"
        default: title
        }
    }

    func axisLabel(_ value: Double) -> String {
        switch self {
        case .cpu:
            value >= 10
                ? "\(Int(value.rounded()))%"
                : String(format: "%.1f%%", value)
        case .memory:
            formatBytes(value)
        case .disk:
            "\(formatBytes(value))/s"
        case .wakeups:
            value >= 10 ? String(Int(value.rounded())) : String(format: "%.1f", value)
        case .processCount:
            String(Int(value.rounded()))
        }
    }

    func guideLabel(
        _ value: Double,
        component: ResultTimelineComponent
    ) -> String {
        switch self {
        case .cpu:
            String(format: "%.1f%%", value)
        case .memory:
            formatBytes(value)
        case .disk:
            "\(component == .diskRead ? "R" : "W") \(formatBytes(value))/s"
        case .wakeups:
            String(format: "%.1f/s", value)
        case .processCount:
            String(Int(value.rounded()))
        }
    }
}

private func timelineStrokeStyle(
    roundNumber: Int,
    isWarmUp: Bool
) -> StrokeStyle {
    if isWarmUp {
        return StrokeStyle(lineWidth: 1.35, dash: [2, 3])
    }
    let patterns: [[CGFloat]] = [
        [],
        [7, 4],
        [2, 3],
        [9, 3, 2, 3],
        [1, 2]
    ]
    return StrokeStyle(
        lineWidth: 1.8,
        lineCap: .round,
        lineJoin: .round,
        dash: patterns[(max(1, roundNumber) - 1) % patterns.count]
    )
}

private func elapsedLabel(_ elapsed: TimeInterval) -> String {
    let prefix = elapsed < 0 ? "−" : ""
    let absolute = abs(elapsed)
    let minutes = Int(absolute) / 60
    let seconds = absolute - Double(minutes * 60)
    if minutes > 0 {
        return String(format: "%@%d:%04.1f", prefix, minutes, seconds)
    }
    return String(format: "%@%.1fs", prefix, seconds)
}

private func formatBytes(_ value: Double) -> String {
    ByteCountFormatter.string(
        fromByteCount: Int64(
            min(max(0, value.rounded()), Double(Int64.max))
        ),
        countStyle: .memory
    )
}

private struct RoundStatusLabel: View {
    let status: SessionRoundStatus

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.35)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color.primary.opacity(0.055), in: Capsule())
            .accessibilityLabel("Round status: \(label.lowercased())")
    }

    private var label: String {
        switch status {
        case .pending: "READY"
        case .activating: "ACTIVATING"
        case .warmingUp: "WARM-UP"
        case .recording: "RECORDING"
        case .completed: "COMPLETE"
        case .failed: "FAILED"
        case .skipped: "SKIPPED"
        case .interrupted: "INTERRUPTED"
        case .cancelled: "CANCELLED"
        }
    }
}

struct SessionNotice: View {
    let message: String
    let isError: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle" : "info.circle")
                .foregroundStyle(isError ? .red : .secondary)
            Text(message)
                .font(.system(size: 12))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss message")
        }
        .padding(12)
        .background(
            Color.primary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

struct SessionSurface<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    init(
        padding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                colorScheme == .dark
                    ? Color(red: 0.125, green: 0.123, blue: 0.119)
                    : Color(red: 0.992, green: 0.988, blue: 0.978),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(
                            contrast == .increased ? 0.24 : 0.09
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color:
                    colorScheme == .dark
                    ? Color.black.opacity(0.18)
                    : Color.black.opacity(0.025),
                radius: 12,
                y: 3
            )
    }
}

private extension View {
    func sessionFieldLabel() -> some View {
        font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    func sessionTextField(minHeight: CGFloat = 38) -> some View {
        padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(
                Color.primary.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.085), lineWidth: 0.75)
            }
    }
}
