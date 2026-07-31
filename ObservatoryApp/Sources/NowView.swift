import AppKit
import Charts
import ObservatoryDomain
import SwiftUI

struct NowView: View {
    @ObservedObject var model: NowViewModel
    let onStartSession: (NowApplicationSnapshot) -> Void

    @AppStorage("now.cpuRepresentation")
    private var cpuRepresentationRaw = CPURepresentation.productDefault.rawValue
    @State private var searchText = ""
    @State private var sort = NowSortOption.name
    @State private var expandedApplications: Set<ApplicationIdentity> = []
    @State private var showsAdvancedProcesses = false
    @State private var isLiveScrolling = false

    private var cpuRepresentation: CPURepresentation {
        CPURepresentation(rawValue: cpuRepresentationRaw)
            ?? CPURepresentation.productDefault
    }

    private var applications: [NowApplicationSnapshot] {
        model.snapshot.applications(matching: searchText, sortedBy: sort)
    }

    var body: some View {
        FloatingPage(
            scrollsContent: false
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DestinationCaption(text: AppDestination.now.caption)

                NowToolStrip(
                    searchText: $searchText,
                    sort: $sort,
                    cpuRepresentationRaw: $cpuRepresentationRaw,
                    isPaused: $model.isVisualUpdatesPaused,
                    showsAdvanced: $showsAdvancedProcesses
                )

                if let notice = model.notice {
                    NowNotice(message: notice, onDismiss: model.dismissNotice)
                }

                NowLiveStatus(
                    applicationCount: applications.count,
                    capturedAt: model.snapshot.capturedAt,
                    isPaused: model.isVisualUpdatesPaused
                )

                content

                if !model.isLoading && !model.snapshot.applications.isEmpty {
                    NowLiveTotalsPlot(
                        points: model.timelinePoints,
                        cpuRepresentation: cpuRepresentation
                    )
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            // Live readings arrive every second. Keep them outside interaction
            // transactions so a hover or disclosure never animates the full tree.
            .animation(nil, value: model.snapshot.capturedAt)
            .background {
                LiveScrollObserver { isScrolling in
                    guard isLiveScrolling != isScrolling else { return }
                    isLiveScrolling = isScrolling
                    model.setScrollRenderingSuspended(isScrolling)
                }
                .frame(width: 0, height: 0)
            }
        }
        .task {
            await model.run()
        }
        .onDisappear {
            isLiveScrolling = false
            model.setScrollRenderingSuspended(false)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            NowLoadingState()
        } else if model.snapshot.applications.isEmpty {
            FloatingEmptyState(
                systemImage: "gauge.open.with.lines.needle.33percent",
                eyebrow: "LIVE APPLICATIONS",
                accent: EditorialPalette.lime,
                title: "Nothing to inspect yet",
                message: "Running applications and their combined resource use will appear as applications launch."
            )
        } else if applications.isEmpty {
            NowNoSearchResults(searchText: searchText)
        } else {
            NowApplicationList(
                applications: applications,
                cpuRepresentation: cpuRepresentation,
                expandedApplications: expandedApplications,
                showsAdvancedProcesses: showsAdvancedProcesses,
                isLiveScrolling: isLiveScrolling,
                ruleActionInProgress: model.ruleActionInProgress,
                onToggleExpansion: toggleExpansion,
                onRule: setRule,
                onResetRules: {
                    model.resetGroupingRules(for: $0)
                },
                onStartSession: onStartSession,
                advancedContent: advancedProcessesContent
            )
        }
    }

    private var advancedProcessesContent: AnyView? {
        guard showsAdvancedProcesses else { return nil }
        return AnyView(
            UnassignedProcessesPanel(
                processes: model.snapshot.unassignedProcesses,
                systemProcessCount: model.snapshot.systemProcessCount,
                applications: model.snapshot.applications,
                ruleActionInProgress: model.ruleActionInProgress,
                onInclude: { process, application in
                    model.setGroupingRule(
                        process: process,
                        application: application,
                        action: .include
                    )
                },
                onResetAll: {
                    model.resetGroupingRules()
                }
            )
        )
    }

    private func toggleExpansion(_ application: ApplicationIdentity) {
        // Expanding a process group can insert dozens of rows. Interpolating
        // that entire layout competes with the one-second metrics refresh and
        // produces visibly uneven frames, so disclose it atomically.
        if expandedApplications.contains(application) {
            expandedApplications.remove(application)
        } else {
            expandedApplications.insert(application)
        }
    }

    private func setRule(
        _ process: NowProcessSnapshot,
        _ application: ApplicationIdentity,
        _ action: GroupingRuleAction
    ) {
        model.setGroupingRule(
            process: process,
            application: application,
            action: action
        )
    }
}

private struct LiveScrollObserver: NSViewRepresentable {
    let onScrollStateChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollStateChange: onScrollStateChange)
    }

    func makeNSView(context: Context) -> ScrollObserverMarkerView {
        let view = ScrollObserverMarkerView()
        view.onContainingScrollViewChange = { [weak view, weak coordinator = context.coordinator] in
            coordinator?.observe(view?.containingScrollView)
        }
        return view
    }

    func updateNSView(
        _ nsView: ScrollObserverMarkerView,
        context: Context
    ) {
        context.coordinator.onScrollStateChange = onScrollStateChange
        context.coordinator.observe(nsView.containingScrollView)
    }

    static func dismantleNSView(
        _ nsView: ScrollObserverMarkerView,
        coordinator: Coordinator
    ) {
        nsView.onContainingScrollViewChange = nil
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onScrollStateChange: (Bool) -> Void
        private weak var scrollView: NSScrollView?
        private var isScrolling = false
        private var scrollingEndWorkItem: DispatchWorkItem?

        init(onScrollStateChange: @escaping (Bool) -> Void) {
            self.onScrollStateChange = onScrollStateChange
        }

        func observe(_ scrollView: NSScrollView?) {
            guard self.scrollView !== scrollView else { return }
            stopObserving()
            guard let scrollView else { return }
            self.scrollView = scrollView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollWillStart),
                name: NSScrollView.willStartLiveScrollNotification,
                object: scrollView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollDidEnd),
                name: NSScrollView.didEndLiveScrollNotification,
                object: scrollView
            )
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollBoundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        func stopObserving() {
            scrollingEndWorkItem?.cancel()
            scrollingEndWorkItem = nil
            if scrollView != nil {
                NotificationCenter.default.removeObserver(self)
                scrollView = nil
            }
            setScrolling(false)
        }

        @objc
        private func scrollWillStart(_ notification: Notification) {
            setScrolling(true)
        }

        @objc
        private func scrollDidEnd(_ notification: Notification) {
            scheduleScrollingEnd()
        }

        @objc
        private func scrollBoundsDidChange(_ notification: Notification) {
            setScrolling(true)
            scheduleScrollingEnd()
        }

        private func scheduleScrollingEnd() {
            scrollingEndWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.setScrolling(false)
            }
            scrollingEndWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.18,
                execute: workItem
            )
        }

        private func setScrolling(_ isScrolling: Bool) {
            guard self.isScrolling != isScrolling else { return }
            self.isScrolling = isScrolling
            onScrollStateChange(isScrolling)
        }
    }
}

private final class ScrollObserverMarkerView: NSView {
    var onContainingScrollViewChange: (() -> Void)?

    var containingScrollView: NSScrollView? {
        if let enclosingScrollView {
            return enclosingScrollView
        }

        var ancestor = superview
        while let candidate = ancestor {
            if let scrollView = candidate.firstDescendantScrollView() {
                return scrollView
            }
            ancestor = candidate.superview
        }
        return nil
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        onContainingScrollViewChange?()
        notifyAfterHierarchySettles()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onContainingScrollViewChange?()
        notifyAfterHierarchySettles()
    }

    private func notifyAfterHierarchySettles() {
        DispatchQueue.main.async { [weak self] in
            self?.onContainingScrollViewChange?()
        }
    }
}

private extension NSView {
    func firstDescendantScrollView() -> NSScrollView? {
        for subview in subviews {
            if let scrollView = subview as? NSScrollView {
                return scrollView
            }
            if let scrollView = subview.firstDescendantScrollView() {
                return scrollView
            }
        }
        return nil
    }
}

private enum NowToolPanel {
    case sort
    case cpu
}

private struct NowToolStrip: View {
    @Binding var searchText: String
    @Binding var sort: NowSortOption
    @Binding var cpuRepresentationRaw: String
    @Binding var isPaused: Bool
    @Binding var showsAdvanced: Bool

    @State private var activePanel: NowToolPanel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var cpuRepresentation: CPURepresentation {
        CPURepresentation(rawValue: cpuRepresentationRaw)
            ?? CPURepresentation.productDefault
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    search
                        .frame(minWidth: 220, maxWidth: .infinity)
                    controls
                }

                VStack(alignment: .leading, spacing: 8) {
                    search
                    controls
                }
            }
            .padding(7)

            if let activePanel {
                Divider()
                    .opacity(0.55)
                    .padding(.horizontal, 10)

                choiceShelf(for: activePanel)
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(edge, lineWidth: 0.75)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.035),
            radius: 12,
            y: 4
        )
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .easeOut(duration: 0.14),
            value: activePanel
        )
    }

    private var search: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Find an app or process", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .accessibilityLabel("Search applications and processes")
            if !searchText.isEmpty {
                HoverSymbolButton(
                    symbol: "xmark",
                    help: "Clear search",
                    action: { searchText = "" }
                )
            } else {
                Image(systemName: "command")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(
            Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.038),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.5)
        }
    }

    private var controls: some View {
        HStack(spacing: 5) {
            ToolPill(
                title: sort.title,
                symbol: "arrow.up.arrow.down",
                isSelected: activePanel == .sort
            ) {
                activePanel = activePanel == .sort ? nil : .sort
            }
            .help("Sort applications")

            ToolPill(
                title: cpuRepresentation.compactTitle,
                symbol: "gauge.with.dots.needle.50percent",
                isSelected: activePanel == .cpu
            ) {
                activePanel = activePanel == .cpu ? nil : .cpu
            }
            .help("CPU representation")

            HoverSymbolButton(
                symbol: isPaused ? "play.fill" : "pause.fill",
                help: isPaused ? "Resume visual updates" : "Pause visual updates",
                isSelected: isPaused,
                tint: MetricPalette.mint
            ) {
                isPaused.toggle()
            }

            HoverSymbolButton(
                symbol: "slider.horizontal.3",
                help: showsAdvanced
                    ? "Hide advanced processes"
                    : "Show advanced processes",
                isSelected: showsAdvanced,
                tint: MetricPalette.lavender
            ) {
                showsAdvanced.toggle()
            }
        }
    }

    @ViewBuilder
    private func choiceShelf(for panel: NowToolPanel) -> some View {
        switch panel {
        case .sort:
            NowChoiceShelf(
                title: "Arrange by",
                choices: NowSortOption.allCases,
                selection: sort,
                label: \.title,
                onSelect: {
                    sort = $0
                    activePanel = nil
                }
            )
        case .cpu:
            NowChoiceShelf(
                title: "Show CPU as",
                choices: CPURepresentation.allCases,
                selection: cpuRepresentation,
                label: \.choiceTitle,
                onSelect: {
                    cpuRepresentationRaw = $0.rawValue
                    activePanel = nil
                }
            )
        }
    }

    private var fill: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.123, blue: 0.119)
            : Color(red: 0.992, green: 0.988, blue: 0.978)
    }

    private var edge: Color {
        Color.primary.opacity(
            contrast == .increased
                ? (colorScheme == .dark ? 0.30 : 0.19)
                : (colorScheme == .dark ? 0.14 : 0.075)
        )
    }
}

private struct ToolPill: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(isSelected ? 180 : 0))
                    .opacity(0.55)
            }
            .padding(.horizontal, 9)
            .frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(
            SoftHoverButtonStyle(
                isSelected: isSelected,
                tint: MetricPalette.peach
            )
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct HoverSymbolButton: View {
    let symbol: String
    let help: String
    var isSelected = false
    var tint = MetricPalette.blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(SoftHoverButtonStyle(isSelected: isSelected, tint: tint))
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct SoftHoverButtonStyle: ButtonStyle {
    let isSelected: Bool
    let tint: Color
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected || isHovering ? Color.primary : Color.secondary)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.primary.opacity(0.085)
                            : Color.primary.opacity(isHovering ? 0.05 : 0)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.primary.opacity(0.13)
                            : Color.primary.opacity(isHovering ? 0.06 : 0),
                        lineWidth: 0.65
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .workspaceHover($isHovering)
    }
}

private struct NowChoiceShelf<Choice: Hashable>: View {
    let title: String
    let choices: [Choice]
    let selection: Choice
    let label: (Choice) -> String
    let onSelect: (Choice) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 5)

            ForEach(choices, id: \.self) { choice in
                Button {
                    onSelect(choice)
                } label: {
                    HStack(spacing: 6) {
                        if choice == selection {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        Text(label(choice))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 29)
                    .contentShape(Capsule())
                }
                .buttonStyle(
                    SoftHoverButtonStyle(
                        isSelected: choice == selection,
                        tint: MetricPalette.lavender
                    )
                )
                .accessibilityAddTraits(choice == selection ? [.isSelected] : [])
            }

            Spacer(minLength: 0)
        }
    }
}

private struct NowLiveStatus: View {
    let applicationCount: Int
    let capturedAt: Date
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isPaused ? MetricPalette.peach : MetricPalette.mint)
                .frame(width: 7, height: 7)
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
                .accessibilityHidden(true)

            Text(isPaused ? "View paused" : "Live")
                .font(.system(size: 11, weight: .semibold))

            Text("·")
                .foregroundStyle(.quaternary)

            Text("\(applicationCount) \(applicationCount == 1 ? "application" : "applications")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            if isPaused {
                Text("Collection continues")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if capturedAt != .distantPast {
                Text(capturedAt.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isPaused
                ? "Visual updates paused. Collection continues."
                : "Live. \(applicationCount) applications."
        )
    }
}

private enum MetricPalette {
    static let blue = Color(red: 0.43, green: 0.55, blue: 0.62)
    static let lavender = Color(red: 0.56, green: 0.52, blue: 0.59)
    static let mint = Color(red: 0.43, green: 0.59, blue: 0.51)
    static let peach = Color(red: 0.69, green: 0.50, blue: 0.41)
    static let butter = Color(red: 0.68, green: 0.58, blue: 0.39)
    static let coral = Color(red: 0.72, green: 0.42, blue: 0.38)
    static let cyan = Color(red: 0.31, green: 0.60, blue: 0.65)
}

private extension ResultTimelineMetric {
    var liveTint: Color {
        switch self {
        case .cpu: MetricPalette.blue
        case .memory: MetricPalette.lavender
        case .disk: MetricPalette.mint
        case .wakeups: MetricPalette.butter
        case .processCount: MetricPalette.peach
        }
    }

    func liveFormatted(
        _ value: Double,
        cpuRepresentation: CPURepresentation,
        compact: Bool = false
    ) -> String {
        switch self {
        case .cpu:
            switch cpuRepresentation {
            case .cores:
                return "\(value.formatted(.number.precision(.fractionLength(compact ? 1 : 2))))c"
            case .activityMonitorPercentage, .totalCapacityPercentage:
                return "\(value.formatted(.number.precision(.fractionLength(value < 10 ? 1 : 0))))%"
            }
        case .memory:
            return Self.binaryBytes(value)
        case .disk:
            return Self.binaryBytes(value) + "/s"
        case .wakeups:
            return "\(value.formatted(.number.precision(.fractionLength(value < 10 ? 1 : 0))))/s"
        case .processCount:
            return String(Int(value.rounded()))
        }
    }

    private static func binaryBytes(_ value: Double) -> String {
        let units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var scaled = max(value, 0)
        var unit = 0
        while scaled >= 1_024, unit < units.count - 1 {
            scaled /= 1_024
            unit += 1
        }
        let places = unit == 0 ? 0 : (scaled < 10 ? 1 : 0)
        return "\(scaled.formatted(.number.precision(.fractionLength(places)))) \(units[unit])"
    }
}

private enum NowLiveSeriesSelection: Equatable {
    case total
    case application(ApplicationIdentity)
}

private struct NowLivePlotSelection {
    let point: NowTimelinePoint
    let series: NowLiveSeriesSelection
    let title: String
    let value: Double
    let color: Color
}

private struct NowLiveTotalsPlot: View {
    let points: [NowTimelinePoint]
    let cpuRepresentation: CPURepresentation

    @State private var metric = ResultTimelineMetric.cpu
    @State private var showsApplications = false
    @State private var usesSystemScale = false
    @State private var selectedTime: Date?
    @State private var selectedSeries: NowLiveSeriesSelection?

    private let systemCapacity = NowTimelineSystemCapacity(
        logicalProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
    )
    private let windowDuration: TimeInterval = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    heading
                    Spacer(minLength: 12)
                    TimelineMetricShelf(metric: $metric)
                    systemScaleShelf
                    applicationToggle
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        heading
                        Spacer()
                        systemScaleShelf
                        applicationToggle
                    }
                    TimelineMetricShelf(metric: $metric)
                }
            }

            liveChart

            if showsApplications {
                applicationLegend
            }
        }
        .padding(14)
        .background(
            Color.primary.opacity(0.032),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
        }
        .onChange(of: showsApplications) {
            if !showsApplications,
               case .application = selectedSeries {
                selectedSeries = .total
            }
        }
    }

    private var liveChart: some View {
        Chart {
            ForEach(points) { point in
                totalMark(for: point)
                applicationMarks(for: point)
            }
            selectionMarks
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
                    if let date = value.as(Date.self) {
                        Text(relativeTimeLabel(date))
                    }
                }
                .font(.system(size: 9))
            }
        }
        .chartYAxis {
            if isSystemScaleActive {
                AxisMarks(position: .leading, values: systemScaleAxisValues) {
                    value in
                    AxisGridLine()
                        .foregroundStyle(Color.primary.opacity(0.055))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(
                                metric.liveFormatted(
                                    number,
                                    cpuRepresentation: cpuRepresentation,
                                    compact: true
                                )
                            )
                        }
                    }
                    .font(.system(size: 9))
                }
            } else {
                AxisMarks(
                    position: .leading,
                    values: .automatic(desiredCount: 5)
                ) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.primary.opacity(0.055))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(
                                metric.liveFormatted(
                                    number,
                                    cpuRepresentation: cpuRepresentation,
                                    compact: true
                                )
                            )
                        }
                    }
                    .font(.system(size: 9))
                }
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
        .frame(height: showsApplications ? 112 : 128)
        .accessibilityLabel("Live \(metric.title) totals")
        .accessibilityValue(
            plotSelection.map {
                "\($0.title), \(formatted($0.value)), \($0.point.capturedAt.formatted(date: .omitted, time: .standard))"
            } ?? latestTotalDescription
        )
    }

    @ChartContentBuilder
    private func totalMark(for point: NowTimelinePoint) -> some ChartContent {
        if let total = totalValue(for: point) {
            LineMark(
                x: .value("Time", point.capturedAt),
                y: .value(metric.title, total),
                series: .value("Series", "All applications")
            )
            .foregroundStyle(metric.liveTint)
            .lineStyle(
                StrokeStyle(
                    lineWidth: selectedSeries == nil || selectedSeries == .total
                        ? 2.2
                        : 1.1,
                    lineCap: .round
                )
            )
            .opacity(
                selectedSeries == nil || selectedSeries == .total ? 1 : 0.26
            )
            .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private func applicationMarks(
        for point: NowTimelinePoint
    ) -> some ChartContent {
        if showsApplications {
            ForEach(point.applications) { application in
                if let value = value(for: application) {
                    LineMark(
                        x: .value("Time", point.capturedAt),
                        y: .value(metric.title, value),
                        series: .value(
                            "Series",
                            application.application.bundleIdentifier
                        )
                    )
                    .foregroundStyle(color(for: application.application))
                    .lineStyle(strokeStyle(for: application.application))
                    .opacity(opacity(for: application.application))
                }
            }
        }
    }

    @ChartContentBuilder
    private var selectionMarks: some ChartContent {
        if let selection = plotSelection {
            RuleMark(x: .value("Selected time", selection.point.capturedAt))
                .foregroundStyle(selection.color.opacity(0.46))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

            PointMark(
                x: .value("Selected time", selection.point.capturedAt),
                y: .value(metric.title, selection.value)
            )
            .foregroundStyle(selection.color)
            .symbolSize(48)
            .annotation(
                position: .top,
                alignment: annotationAlignment(for: selection.point.capturedAt),
                spacing: 5
            ) {
                selectionLabel(selection)
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Text("Live totals")
                    .font(.system(size: 13, weight: .semibold))
                Text(latestTotalDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(metric.liveTint)
                    .monospacedDigit()
            }
            Text("Combined running applications · last 60 seconds")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var applicationToggle: some View {
        SessionToggleButton(
            title: "Applications",
            isOn: $showsApplications
        )
        .help(
            showsApplications
                ? "Hide individual application lines"
                : "Add a line for each running application"
        )
    }

    private var applicationLegend: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                legendItem(
                    title: "All applications",
                    color: metric.liveTint,
                    style: StrokeStyle(lineWidth: 2.2),
                    series: .total
                )
                ForEach(timelineApplications) { application in
                    legendItem(
                        title: application.displayName,
                        color: color(for: application.application),
                        style: baseStrokeStyle(for: application.application),
                        series: .application(application.application)
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: 14)
    }

    private func legendItem(
        title: String,
        color: Color,
        style: StrokeStyle,
        series: NowLiveSeriesSelection
    ) -> some View {
        Button {
            select(series)
        } label: {
            HStack(spacing: 5) {
                TimelineLegendLine(style: style, color: color)
                    .frame(width: 18, height: 6)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(
                        selectedSeries == nil || selectedSeries == series
                            ? 0.62
                            : 0.34
                    ))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                select(series)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint("Highlight this plot line")
    }

    private var timelineApplications: [NowTimelineApplicationPoint] {
        var byIdentity: [ApplicationIdentity: NowTimelineApplicationPoint] = [:]
        for point in points {
            for application in point.applications {
                byIdentity[application.application] = application
            }
        }
        return byIdentity.values.sorted {
            $0.displayName.localizedStandardCompare($1.displayName)
                == .orderedAscending
        }
    }

    private var xDomain: ClosedRange<Date> {
        let end = points.last?.capturedAt ?? Date()
        return end.addingTimeInterval(-windowDuration)...end
    }

    private var yDomain: ClosedRange<Double> {
        let maximum = plottedValues.max() ?? 0
        if isSystemScaleActive, let systemCapacityValue {
            return 0...max(systemCapacityValue, maximum * 1.02)
        }
        return 0...max(maximum * 1.12, minimumYMaximum)
    }

    private var minimumYMaximum: Double {
        switch metric {
        case .cpu:
            return cpuRepresentation == .cores ? 1 : 1
        case .memory, .disk:
            return 1_024
        case .wakeups:
            return 1
        case .processCount:
            return 1
        }
    }

    private var systemScaleAxisValues: [Double] {
        let maximum = yDomain.upperBound
        return (0...4).map { maximum * Double($0) / 4 }
    }

    private var plottedValues: [Double] {
        points.flatMap { point -> [Double] in
            var values = [totalValue(for: point)].compactMap { $0 }
            if showsApplications {
                values += point.applications.compactMap { application in
                    value(for: application)
                }
            }
            return values
        }
    }

    private func totalValue(for point: NowTimelinePoint) -> Double? {
        point.totalValue(
            for: metric,
            cpuRepresentation: cpuRepresentation,
            logicalProcessorCount: systemCapacity.logicalProcessorCount
        )
    }

    private func value(for application: NowTimelineApplicationPoint) -> Double? {
        application.value(
            for: metric,
            cpuRepresentation: cpuRepresentation,
            logicalProcessorCount: systemCapacity.logicalProcessorCount
        )
    }

    private var latestTotalDescription: String {
        guard
            let point = points.last,
            let total = totalValue(for: point)
        else {
            return "Unavailable"
        }
        let formattedTotal = metric.liveFormatted(
            total,
            cpuRepresentation: cpuRepresentation
        )
        guard isSystemScaleActive, let systemCapacityValue else {
            return formattedTotal
        }
        let formattedCapacity = metric.liveFormatted(
            systemCapacityValue,
            cpuRepresentation: cpuRepresentation
        )
        return "\(formattedTotal) of \(formattedCapacity)"
    }

    private var systemCapacityValue: Double? {
        systemCapacity.value(
            for: metric,
            cpuRepresentation: cpuRepresentation
        )
    }

    private var isSystemScaleActive: Bool {
        usesSystemScale && systemCapacityValue != nil
    }

    private var systemScaleShelf: some View {
        HStack(spacing: 4) {
            SessionChoiceButton(
                title: "Fit",
                isSelected: !isSystemScaleActive,
                compact: true
            ) {
                usesSystemScale = false
            }
            SessionChoiceButton(
                title: "System",
                isSelected: isSystemScaleActive,
                compact: true
            ) {
                usesSystemScale = true
            }
            .disabled(systemCapacityValue == nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vertical chart scale")
        .help(systemScaleHelp)
    }

    private var systemScaleHelp: String {
        guard let systemCapacityValue else {
            return "This metric has no fixed system capacity, so the chart fits the recorded values."
        }
        let formattedCapacity = metric.liveFormatted(
            systemCapacityValue,
            cpuRepresentation: cpuRepresentation
        )
        return "Scale the chart to this Mac's \(formattedCapacity) \(metric.title.lowercased()) capacity."
    }

    private func color(for application: ApplicationIdentity) -> Color {
        let palette = [
            MetricPalette.cyan,
            MetricPalette.lavender,
            MetricPalette.mint,
            MetricPalette.coral,
            MetricPalette.butter,
            MetricPalette.blue,
            MetricPalette.peach,
        ]
        let index = timelineApplications.firstIndex {
            $0.application == application
        } ?? 0
        return palette[index % palette.count]
    }

    private func baseStrokeStyle(
        for application: ApplicationIdentity
    ) -> StrokeStyle {
        let patterns: [[CGFloat]] = [
            [],
            [7, 3],
            [2, 3],
            [9, 3, 2, 3],
            [1, 2],
        ]
        let index = timelineApplications.firstIndex {
            $0.application == application
        } ?? 0
        return StrokeStyle(
            lineWidth: 1.1,
            lineCap: .round,
            dash: patterns[index % patterns.count]
        )
    }

    private func strokeStyle(
        for application: ApplicationIdentity
    ) -> StrokeStyle {
        let base = baseStrokeStyle(for: application)
        let isSelected = selectedSeries == .application(application)
        return StrokeStyle(
            lineWidth: isSelected ? 2.5 : base.lineWidth,
            lineCap: base.lineCap,
            lineJoin: base.lineJoin,
            miterLimit: base.miterLimit,
            dash: base.dash,
            dashPhase: base.dashPhase
        )
    }

    private func opacity(for application: ApplicationIdentity) -> Double {
        guard let selectedSeries else { return 0.72 }
        return selectedSeries == .application(application) ? 1 : 0.18
    }

    private var plotSelection: NowLivePlotSelection? {
        guard
            let selectedTime,
            let selectedSeries,
            let point = points.first(where: { $0.capturedAt == selectedTime })
        else {
            return nil
        }

        switch selectedSeries {
        case .total:
            guard let value = totalValue(for: point) else { return nil }
            return NowLivePlotSelection(
                point: point,
                series: .total,
                title: "All applications",
                value: value,
                color: metric.liveTint
            )
        case .application(let identity):
            guard
                let application = point.applications.first(where: {
                    $0.application == identity
                }),
                let value = value(for: application)
            else {
                return nil
            }
            return NowLivePlotSelection(
                point: point,
                series: .application(identity),
                title: application.displayName,
                value: value,
                color: color(for: identity)
            )
        }
    }

    private func updateSelection(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let plotX = location.x - frame.minX
        let plotY = location.y - frame.minY
        guard
            plotX >= 0,
            plotX <= frame.width,
            plotY >= 0,
            plotY <= frame.height,
            let date: Date = proxy.value(atX: plotX),
            let point = points.min(by: {
                abs($0.capturedAt.timeIntervalSince(date))
                    < abs($1.capturedAt.timeIntervalSince(date))
            })
        else {
            return
        }

        var candidates: [(series: NowLiveSeriesSelection, value: Double)] = []
        if let total = totalValue(for: point) {
            candidates.append((.total, total))
        }
        if showsApplications {
            candidates += point.applications.compactMap { application in
                value(for: application).map {
                    (.application(application.application), $0)
                }
            }
        }
        guard
            let nearest = candidates.min(by: { lhs, rhs in
                let lhsY = proxy.position(forY: lhs.value) ?? 0
                let rhsY = proxy.position(forY: rhs.value) ?? 0
                return abs(lhsY - plotY) < abs(rhsY - plotY)
            })
        else {
            return
        }

        selectedTime = point.capturedAt
        selectedSeries = nearest.series
    }

    private func select(_ series: NowLiveSeriesSelection) {
        guard
            let point = points.reversed().first(where: { point in
                switch series {
                case .total:
                    totalValue(for: point) != nil
                case .application(let identity):
                    point.applications.contains {
                        $0.application == identity && value(for: $0) != nil
                    }
                }
            })
        else {
            return
        }
        selectedTime = point.capturedAt
        selectedSeries = series
    }

    private func formatted(_ value: Double) -> String {
        metric.liveFormatted(value, cpuRepresentation: cpuRepresentation)
    }

    private func annotationAlignment(for date: Date) -> Alignment {
        let midpoint = xDomain.lowerBound.addingTimeInterval(windowDuration / 2)
        return date > midpoint ? .trailing : .leading
    }

    private func selectionLabel(_ selection: NowLivePlotSelection) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(selection.title)
                .font(.system(size: 10, weight: .semibold))
            Text(
                "\(formatted(selection.value)) · \(selection.point.capturedAt.formatted(date: .omitted, time: .standard))"
            )
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.96),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(selection.color.opacity(0.5), lineWidth: 0.75)
        }
        .accessibilityHidden(true)
    }

    private func relativeTimeLabel(_ date: Date) -> String {
        let seconds = Int(date.timeIntervalSince(xDomain.upperBound).rounded())
        return seconds >= 0 ? "Now" : "\(seconds)s"
    }
}

private struct NowApplicationList: View {
    let applications: [NowApplicationSnapshot]
    let cpuRepresentation: CPURepresentation
    let expandedApplications: Set<ApplicationIdentity>
    let showsAdvancedProcesses: Bool
    let isLiveScrolling: Bool
    let ruleActionInProgress: Bool
    let onToggleExpansion: (ApplicationIdentity) -> Void
    let onRule: (
        NowProcessSnapshot,
        ApplicationIdentity,
        GroupingRuleAction
    ) -> Void
    let onResetRules: (ApplicationIdentity) -> Void
    let onStartSession: (NowApplicationSnapshot) -> Void
    let advancedContent: AnyView?

    var body: some View {
        let ledgerRows = rows

        List {
            NowListHeader()
                .padding(.horizontal, 14)
                .modifier(LedgerListRowChrome(position: .top))

            ForEach(Array(ledgerRows.enumerated()), id: \.element.id) {
                index, row in
                let isLast = index == ledgerRows.count - 1
                rowView(for: row, isLastInLedger: isLast)
                    .modifier(
                        LedgerListRowChrome(
                            position: isLast ? .bottom : .middle
                        )
                    )
            }

            if let advancedContent {
                advancedContent
                    .padding(.horizontal, 5)
                    .padding(.top, 16)
                    .padding(.bottom, 5)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .frame(minHeight: 180, maxHeight: .infinity)
    }

    private var rows: [NowApplicationListRow] {
        applications.flatMap { application in
            let isExpanded = expandedApplications.contains(application.id)
            var rows: [NowApplicationListRow] = [
                .application(application, isExpanded: isExpanded),
            ]
            guard isExpanded else { return rows }

            rows.append(.processHeader(application))
            guard !application.members.isEmpty else {
                rows.append(.emptyProcesses(application.id))
                return rows
            }

            rows.append(.processMetricHeader(application.id))
            for index in stride(
                from: 0,
                to: application.members.count,
                by: 2
            ) {
                rows.append(
                    .processPair(
                        application: application.id,
                        primary: application.members[index],
                        secondary: application.members.indices.contains(index + 1)
                            ? application.members[index + 1]
                            : nil,
                        isLast: index + 2 >= application.members.count
                    )
                )
            }
            return rows
        }
    }

    @ViewBuilder
    private func rowView(
        for row: NowApplicationListRow,
        isLastInLedger: Bool
    ) -> some View {
        Group {
            switch row {
            case let .application(application, isExpanded):
                ApplicationListRow(
                    snapshot: application,
                    cpuRepresentation: cpuRepresentation,
                    isExpanded: isExpanded,
                    onToggleExpansion: {
                        onToggleExpansion(application.id)
                    },
                    onStartSession: {
                        onStartSession(application)
                    },
                    showsBottomSeparator: !isLastInLedger
                )

            case let .processHeader(application):
                ProcessDisclosureHeader(
                    snapshot: application,
                    isLiveScrolling: isLiveScrolling,
                    onResetRules: {
                        onResetRules(application.id)
                    }
                )

            case .processMetricHeader:
                ProcessMetricHeaderRow(isLiveScrolling: isLiveScrolling)

            case let .processPair(
                application,
                primary,
                secondary,
                isLast
            ):
                ProcessLedgerPairRow(
                    primary: primary,
                    secondary: secondary,
                    showsAdvanced: showsAdvancedProcesses,
                    isLiveScrolling: isLiveScrolling,
                    ruleActionInProgress: ruleActionInProgress,
                    isLast: isLast,
                    onRule: {
                        onRule($0, application, $1)
                    }
                )

            case .emptyProcesses:
                EmptyProcessLedgerRow(isLiveScrolling: isLiveScrolling)
            }
        }
    }
}

private enum LedgerListRowPosition {
    case top
    case middle
    case bottom
}

private struct LedgerListRowChrome: ViewModifier {
    let position: LedgerListRowPosition

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background {
                LedgerListRowShape(position: position)
                    .fill(surfaceColor)
            }
            .overlay {
                LedgerListRowBorder(position: position)
                    .stroke(
                        Color.primary.opacity(
                            contrast == .increased ? 0.18 : 0.075
                        ),
                        lineWidth: 0.75
                    )
            }
            .padding(.horizontal, 5)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.123, blue: 0.119)
            : Color(red: 0.992, green: 0.988, blue: 0.978)
    }
}

private struct LedgerListRowShape: Shape {
    let position: LedgerListRowPosition
    private let cornerRadius: CGFloat = 19

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height)
        var path = Path()

        switch position {
        case .top:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()

        case .middle:
            path.addRect(rect)

        case .bottom:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }

        return path
    }
}

private struct LedgerListRowBorder: Shape {
    let position: LedgerListRowPosition
    private let cornerRadius: CGFloat = 19

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height)
        var path = Path()

        switch position {
        case .top:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        case .middle:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        case .bottom:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        return path
    }
}

private enum NowApplicationListRowID: Hashable {
    case application(ApplicationIdentity)
    case processHeader(ApplicationIdentity)
    case processMetricHeader(ApplicationIdentity)
    case processPair(ApplicationIdentity, ProcessIdentity)
    case emptyProcesses(ApplicationIdentity)
}

private enum NowApplicationListRow: Identifiable {
    case application(NowApplicationSnapshot, isExpanded: Bool)
    case processHeader(NowApplicationSnapshot)
    case processMetricHeader(ApplicationIdentity)
    case processPair(
        application: ApplicationIdentity,
        primary: NowProcessSnapshot,
        secondary: NowProcessSnapshot?,
        isLast: Bool
    )
    case emptyProcesses(ApplicationIdentity)

    var id: NowApplicationListRowID {
        switch self {
        case let .application(application, _):
            return .application(application.id)
        case let .processHeader(application):
            return .processHeader(application.id)
        case let .processMetricHeader(application):
            return .processMetricHeader(application)
        case let .processPair(application, primary, _, _):
            return .processPair(application, primary.id)
        case let .emptyProcesses(application):
            return .emptyProcesses(application)
        }
    }
}

private struct NowListHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Application")
                .frame(minWidth: 170, maxWidth: .infinity, alignment: .leading)
            Text("CPU")
                .frame(width: 72, alignment: .trailing)
            Text("Memory")
                .frame(width: 92, alignment: .trailing)
            Text("Disk I/O")
                .frame(width: 138, alignment: .trailing)
            Text("Wakeups")
                .frame(width: 70, alignment: .trailing)
            Text("Procs")
                .frame(width: 48, alignment: .trailing)
            Color.clear
                .frame(width: 56)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .tracking(0.5)
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}

private struct ApplicationListRow: View {
    let snapshot: NowApplicationSnapshot
    let cpuRepresentation: CPURepresentation
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onStartSession: () -> Void
    let showsBottomSeparator: Bool

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    private let logicalProcessorCount = ProcessInfo.processInfo.activeProcessorCount

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleExpansion) {
                HStack(spacing: 10) {
                    ApplicationIcon(
                        bundleURL: snapshot.application.identity.bundleURL,
                        size: 34
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.application.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            ActivityStateDot(state: snapshot.state)
                            Text(snapshot.state.title)
                            if snapshot.isPartialTotal {
                                Image(systemName: "exclamationmark.circle")
                                    .help(
                                        snapshot.partialExplanation
                                            ?? "Some data is incomplete."
                                    )
                            }
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)
                }
                .frame(minWidth: 170, maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(snapshot.application.displayName)
            .accessibilityHint(
                isExpanded ? "Collapse process details" : "Expand process details"
            )

            ListMetric(
                title: "CPU",
                value: NowMetricFormatter.cpu(
                    snapshot.metrics.cpuCoreUsage,
                    representation: cpuRepresentation,
                    logicalProcessorCount: logicalProcessorCount
                ),
                width: 72,
                accent: MetricPalette.blue
            )
            .help(
                NowMetricFormatter.cpuHelp(
                    snapshot.metrics.cpuCoreUsage,
                    logicalProcessorCount: logicalProcessorCount
                )
            )
            ListMetric(
                title: "Memory",
                value: NowMetricFormatter.bytes(
                    snapshot.metrics.physicalMemoryBytes
                ),
                width: 92,
                accent: MetricPalette.lavender
            )
            ListMetric(
                title: "Disk",
                value: NowMetricFormatter.disk(
                    read: snapshot.metrics.diskReadBytesPerSecond,
                    write: snapshot.metrics.diskWriteBytesPerSecond
                ),
                width: 138,
                accent: MetricPalette.mint
            )
            ListMetric(
                title: "Wakeups",
                value: NowMetricFormatter.wakeups(
                    snapshot.metrics.wakeupsPerSecond
                ),
                width: 70,
                accent: MetricPalette.butter
            )
            ListMetric(
                title: "Processes",
                value: "\(snapshot.metrics.processCount)",
                width: 48,
                accent: .secondary
            )

            HStack(spacing: 3) {
                HoverSymbolButton(
                    symbol: "record.circle",
                    help: "Start a controlled test",
                    tint: MetricPalette.peach,
                    action: onStartSession
                )
                HoverSymbolButton(
                    symbol: "chevron.right",
                    help: isExpanded
                        ? "Collapse process details"
                        : "Expand process details",
                    isSelected: isExpanded,
                    tint: MetricPalette.blue,
                    action: onToggleExpansion
                )
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(
                    .easeOut(duration: 0.12),
                    value: isExpanded
                )
            }
            .frame(width: 56)
            .opacity(isHovering || isExpanded ? 1 : 0.5)
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 54)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowSurface)
        }
        .overlay(alignment: .bottom) {
            if !isExpanded, showsBottomSeparator {
                Rectangle()
                    .fill(Color.primary.opacity(0.055))
                    .frame(height: 0.5)
                    .padding(.horizontal, 10)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .workspaceHover($isHovering)
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }

    private var rowSurface: Color {
        guard isHovering || isExpanded else { return .clear }
        if isHovering {
            return Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.032)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.018)
    }
}

private struct ListMetric: View {
    let title: String
    let value: String
    let width: CGFloat
    let accent: Color

    @State private var isHovering = false

    var body: some View {
        Text(value)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: width, alignment: .trailing)
            .overlay(alignment: .bottomTrailing) {
                Capsule()
                    .fill(accent)
                    .frame(width: 18, height: 2)
                    .opacity(isHovering ? 1 : 0.35)
                    .offset(y: 5)
            }
            .workspaceHover($isHovering)
            .animation(.easeOut(duration: 0.1), value: isHovering)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(value)
    }
}

private struct ProcessDisclosureHeader: View {
    let snapshot: NowApplicationSnapshot
    let isLiveScrolling: Bool
    let onResetRules: () -> Void

    var body: some View {
        HStack {
            Text("Processes")
                .font(.system(size: 12, weight: .semibold))
            Text("\(snapshot.members.count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .frame(height: 18)
                .background(Color.primary.opacity(0.05), in: Capsule())
            Spacer()
            if snapshot.members.contains(where: {
                $0.ownership.evidence.contains(.manualInclude)
            }) {
                Button("Reset rules", action: onResetRules)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 5)
        .padding(.bottom, 5)
        .allowsHitTesting(!isLiveScrolling)
    }
}

private struct ProcessMetricHeaderRow: View {
    let isLiveScrolling: Bool

    private let minimumColumnWidth: CGFloat = 340
    private let columnSpacing: CGFloat = 12

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: columnSpacing) {
                ProcessMetricHeader()
                ProcessMetricHeader()
            }
            .frame(minWidth: minimumColumnWidth * 2 + columnSpacing)

            ProcessMetricHeader()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
        .allowsHitTesting(!isLiveScrolling)
    }
}

private struct ProcessLedgerPairRow: View {
    let primary: NowProcessSnapshot
    let secondary: NowProcessSnapshot?
    let showsAdvanced: Bool
    let isLiveScrolling: Bool
    let ruleActionInProgress: Bool
    let isLast: Bool
    let onRule: (
        NowProcessSnapshot,
        GroupingRuleAction
    ) -> Void

    private let minimumColumnWidth: CGFloat = 340
    private let columnSpacing: CGFloat = 12

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: columnSpacing) {
                row(for: primary)

                if let secondary {
                    row(for: secondary)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
                .frame(minWidth: minimumColumnWidth * 2 + columnSpacing)

            VStack(spacing: 0) {
                row(for: primary)
                if let secondary {
                    row(for: secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, isLast ? 12 : 0)
        // During a live gesture the ledger should only translate. Prevent
        // rows passing under a stationary pointer from producing hover work.
        .allowsHitTesting(!isLiveScrolling)
        .transaction { transaction in
            if isLiveScrolling {
                transaction.animation = nil
            }
        }
    }

    private func row(for process: NowProcessSnapshot) -> some View {
        ProcessRow(
            process: process,
            showsAdvanced: showsAdvanced,
            isLiveScrolling: isLiveScrolling,
            ruleActionInProgress: ruleActionInProgress,
            onRule: { onRule(process, $0) }
        )
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyProcessLedgerRow: View {
    let isLiveScrolling: Bool

    var body: some View {
        Text("No measurable process details are available.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .allowsHitTesting(!isLiveScrolling)
    }
}

private struct ProcessMetricHeader: View {
    private let labels = [
        "CPU",
        "Memory",
        "Disk",
        "Wakeups",
        "Threads",
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .tracking(0.35)
        .padding(.horizontal, 8)
        .frame(height: 20)
        .accessibilityHidden(true)
    }
}

private struct ProcessRow: View {
    let process: NowProcessSnapshot
    let showsAdvanced: Bool
    let isLiveScrolling: Bool
    let ruleActionInProgress: Bool
    let onRule: (GroupingRuleAction) -> Void
    @State private var isHovering = false
    @State private var showsRuleActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(process.displayName)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .layoutPriority(1)

                Text("PID \(process.process.identity.processIdentifier)")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)

                Spacer(minLength: 4)

                ConfidenceLabel(confidence: process.ownership.confidence)
                    .fixedSize()

                if process.ownership.confidence < .high, process.ruleMatcher != nil {
                    Button {
                        showsRuleActions.toggle()
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(
                        SoftHoverButtonStyle(
                            isSelected: showsRuleActions,
                            tint: MetricPalette.lavender
                        )
                    )
                    .disabled(ruleActionInProgress)
                    .help("Process ownership actions")
                    .accessibilityLabel(
                        "Ownership actions for \(process.displayName)"
                    )
                    .opacity(showsHover ? 1 : 0.55)
                }
            }

            if showsRuleActions {
                HStack(spacing: 6) {
                    Text("Ownership")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    InlineChoiceButton(
                        title: "Always include",
                        symbol: "plus.circle",
                        tint: MetricPalette.mint
                    ) {
                        showsRuleActions = false
                        onRule(.include)
                    }

                    InlineChoiceButton(
                        title: "Always exclude",
                        symbol: "minus.circle",
                        tint: MetricPalette.peach
                    ) {
                        showsRuleActions = false
                        onRule(.exclude)
                    }
                }
                .transition(.opacity)
            }

            HStack(spacing: 6) {
                ProcessMetric(
                    label: "CPU",
                    value: NowMetricFormatter.processCPU(process.sample?.cpuCoreUsage)
                )
                .equatable()
                ProcessMetric(
                    label: "Memory",
                    value: NowMetricFormatter.bytes(process.sample?.physicalMemoryBytes)
                )
                .equatable()
                ProcessMetric(
                    label: "Disk",
                    value: NowMetricFormatter.compactDisk(
                        read: process.sample?.diskReadBytesPerSecond,
                        write: process.sample?.diskWriteBytesPerSecond
                    )
                )
                .equatable()
                ProcessMetric(
                    label: "Wakeups",
                    value: NowMetricFormatter.compactRate(
                        process.sample?.wakeupsPerSecond
                    )
                )
                .equatable()
                ProcessMetric(
                    label: "Threads",
                    value: process.sample?.threadCount.map(String.init) ?? "—"
                )
                .equatable()
            }

            if showsAdvanced {
                Text(process.ownership.evidence.evidenceDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                if let path = process.process.identity.executablePath {
                    Text(path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color.primary.opacity(showsHover ? 0.035 : 0),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.055))
                .frame(height: 0.5)
                .padding(.horizontal, 8)
                .opacity(showsHover ? 0 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .workspaceHover($isHovering)
        .onChange(of: isLiveScrolling) { _, isScrolling in
            if isScrolling {
                isHovering = false
            }
        }
        .onChange(of: process.id) {
            isHovering = false
        }
        .animation(.easeOut(duration: 0.1), value: showsHover)
        .animation(.easeOut(duration: 0.12), value: showsRuleActions)
        .accessibilityElement(children: .contain)
    }

    private var showsHover: Bool {
        isHovering && !isLiveScrolling
    }
}

private struct InlineChoiceButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 8)
                .frame(height: 25)
                .contentShape(Capsule())
        }
        .buttonStyle(SoftHoverButtonStyle(isSelected: false, tint: tint))
    }
}

private struct ProcessMetric: View, Equatable {
    let label: String
    let value: String

    var body: some View {
        Text(value)
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct UnassignedProcessesPanel: View {
    let processes: [NowProcessSnapshot]
    let systemProcessCount: Int
    let applications: [NowApplicationSnapshot]
    let ruleActionInProgress: Bool
    let onInclude: (NowProcessSnapshot, ApplicationIdentity) -> Void
    let onResetAll: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Unassigned processes")
                        .font(.system(size: 15, weight: .semibold))
                    Text(
                        "System processes and uncertain ownership are excluded from application totals."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset all rules", action: onResetAll)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .disabled(ruleActionInProgress)
            }

            if processes.isEmpty {
                Text(
                    systemProcessCount == 0
                        ? "Every discovered process has a clear owner."
                        : "\(systemProcessCount) system-only processes are outside application totals."
                )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(processes) { process in
                        UnassignedProcessRow(
                            process: process,
                            candidates: candidateApplications(for: process),
                            isDisabled: ruleActionInProgress,
                            onInclude: {
                                onInclude(process, $0)
                            }
                        )
                    }
                }
            }

            if !processes.isEmpty, systemProcessCount > 0 {
                Text(
                    "\(systemProcessCount) additional system-only processes have no application evidence."
                )
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(
            Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.025),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
        }
    }

    private func candidateApplications(
        for process: NowProcessSnapshot
    ) -> [DiscoveredApplication] {
        let candidates = Set(process.ownership.conflictingApplications)
        return applications
            .map(\.application)
            .filter { candidates.contains($0.identity) }
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName)
                    == .orderedAscending
            }
    }
}

private struct UnassignedProcessRow: View {
    let process: NowProcessSnapshot
    let candidates: [DiscoveredApplication]
    let isDisabled: Bool
    let onInclude: (ApplicationIdentity) -> Void

    @State private var showsCandidates = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text("PID \(process.process.identity.processIdentifier)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Spacer()

                if !candidates.isEmpty, process.ruleMatcher != nil {
                    Button {
                        showsCandidates.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            Text("Choose owner")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .rotationEffect(
                                    .degrees(showsCandidates ? 180 : 0)
                                )
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                    }
                    .buttonStyle(
                        SoftHoverButtonStyle(
                            isSelected: showsCandidates,
                            tint: MetricPalette.lavender
                        )
                    )
                    .disabled(isDisabled)
                    .accessibilityLabel(
                        "Choose an owner for \(process.displayName)"
                    )
                } else {
                    Text("No application evidence")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            if showsCandidates {
                HStack(spacing: 6) {
                    Text("Include in")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    ForEach(candidates, id: \.identity) { application in
                        InlineChoiceButton(
                            title: application.displayName,
                            symbol: "plus.circle",
                            tint: MetricPalette.mint
                        ) {
                            showsCandidates = false
                            onInclude(application.identity)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .background(
            Color.primary.opacity(isHovering ? 0.04 : 0),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(isHovering ? 0 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .workspaceHover($isHovering)
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: showsCandidates)
    }
}

private struct ApplicationIcon: View {
    let bundleURL: URL
    var size: CGFloat = 42

    var body: some View {
        Image(nsImage: ApplicationIconCache.image(for: bundleURL))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

@MainActor
private enum ApplicationIconCache {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(for bundleURL: URL) -> NSImage {
        let key = bundleURL as NSURL
        if let image = cache.object(forKey: key) {
            return image
        }
        let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
        cache.setObject(image, forKey: key)
        return image
    }
}

private struct StateLabel: View {
    let state: ApplicationState

    var body: some View {
        Text(state.title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }
}

private struct ActivityStateDot: View {
    let state: ApplicationState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch state {
        case .frontmost: MetricPalette.mint
        case .visible: MetricPalette.blue
        case .hidden: MetricPalette.lavender
        case .idle: Color.secondary.opacity(0.6)
        case .terminated: MetricPalette.peach
        }
    }
}

private struct ConfidenceLabel: View {
    let confidence: GroupingConfidence

    @ViewBuilder
    var body: some View {
        if confidence == .high {
            Image(systemName: confidence.symbolName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityLabel("High ownership confidence")
                .help("High ownership confidence")
        } else {
            Label(confidence.title, systemImage: confidence.symbolName)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .help("\(confidence.title) ownership confidence")
        }
    }
}

private struct NowNotice: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 12))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notice")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct NowLoadingState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Discovering running applications…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
        .accessibilityElement(children: .combine)
    }
}

private struct NowNoSearchResults: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text("No matches")
                .font(.system(size: 16, weight: .semibold))
            Text("No application or owned process matches “\(searchText)”.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private enum NowMetricFormatter {
    static func cpu(
        _ cores: Double?,
        representation: CPURepresentation,
        logicalProcessorCount: Int
    ) -> String {
        guard let cores else { return "Unavailable" }
        let value = representation.value(
            coreUsage: cores,
            logicalProcessorCount: logicalProcessorCount
        )
        switch representation {
        case .cores:
            return "\(decimal(value, places: value < 10 ? 2 : 1)) cores"
        case .activityMonitorPercentage, .totalCapacityPercentage:
            return "\(decimal(value, places: value < 10 ? 1 : 0))%"
        }
    }

    static func cpuHelp(
        _ cores: Double?,
        logicalProcessorCount: Int
    ) -> String {
        guard let cores else {
            return "CPU is unavailable. Values use a five-second rolling average."
        }
        return [
            cpu(
                cores,
                representation: .cores,
                logicalProcessorCount: logicalProcessorCount
            ),
            cpu(
                cores,
                representation: .activityMonitorPercentage,
                logicalProcessorCount: logicalProcessorCount
            ) + " Activity Monitor style",
            cpu(
                cores,
                representation: .totalCapacityPercentage,
                logicalProcessorCount: logicalProcessorCount
            ) + " of total logical CPU",
            "Five-second rolling average"
        ].joined(separator: " · ")
    }

    static func processCPU(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(decimal(value, places: value < 10 ? 2 : 1))c"
    }

    static func bytes(_ value: UInt64?) -> String {
        guard let value else { return "Unavailable" }
        return binaryBytes(Double(value))
    }

    static func disk(read: Double?, write: Double?) -> String {
        switch (read, write) {
        case let (.some(read), .some(write)):
            return "↓ \(rate(read)) · ↑ \(rate(write))"
        case let (.some(read), .none):
            return "↓ \(rate(read)) · ↑ unavailable"
        case let (.none, .some(write)):
            return "↓ unavailable · ↑ \(rate(write))"
        case (.none, .none):
            return "Unavailable"
        }
    }

    static func compactDisk(read: Double?, write: Double?) -> String {
        let values = [read, write].compactMap { $0 }
        guard !values.isEmpty else { return "—" }
        return rate(values.reduce(0, +))
    }

    static func wakeups(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return "\(decimal(value, places: value < 10 ? 1 : 0))/s"
    }

    static func compactRate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(decimal(value, places: value < 10 ? 1 : 0))/s"
    }

    static func wakeupMeaning(_ value: Double?) -> String {
        guard let value else { return "Measurement unavailable" }
        if value < 10 { return "Low background activity" }
        if value < 100 { return "Moderate background activity" }
        return "High background activity"
    }

    static func threadDetail(_ value: Int?) -> String {
        guard let value else { return "Thread count unavailable" }
        return "\(value) \(value == 1 ? "thread" : "threads")"
    }

    private static func rate(_ value: Double) -> String {
        binaryBytes(value) + "/s"
    }

    private static func binaryBytes(_ value: Double) -> String {
        let units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var scaled = max(value, 0)
        var unit = 0
        while scaled >= 1_024, unit < units.count - 1 {
            scaled /= 1_024
            unit += 1
        }
        let places = unit == 0 ? 0 : (scaled < 10 ? 1 : 0)
        return "\(decimal(scaled, places: places)) \(units[unit])"
    }

    private static func decimal(_ value: Double, places: Int) -> String {
        String(format: "%.\(places)f", value)
    }
}

private extension NowSortOption {
    var title: String {
        switch self {
        case .name: "Name"
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .wakeups: "Wakeups"
        case .processCount: "Process count"
        }
    }
}

private extension CPURepresentation {
    var compactTitle: String {
        switch self {
        case .cores: "Cores"
        case .activityMonitorPercentage: "Activity %"
        case .totalCapacityPercentage: "Total %"
        }
    }

    var choiceTitle: String {
        switch self {
        case .cores: "Core equivalents"
        case .activityMonitorPercentage: "Activity Monitor %"
        case .totalCapacityPercentage: "Total capacity %"
        }
    }
}

private extension ApplicationState {
    var title: String {
        switch self {
        case .frontmost: "Frontmost"
        case .visible: "Visible"
        case .hidden: "Hidden"
        case .idle: "Idle"
        case .terminated: "Terminated"
        }
    }
}

private extension GroupingConfidence {
    var title: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .unassigned: "Unassigned"
        }
    }

    var symbolName: String {
        switch self {
        case .high: "checkmark.circle"
        case .medium: "circle.lefthalf.filled"
        case .low: "exclamationmark.circle"
        case .unassigned: "questionmark.circle"
        }
    }
}

private extension Array where Element == OwnershipEvidence {
    var evidenceDescription: String {
        guard !isEmpty else { return "No ownership evidence" }
        return "Evidence: " + map(\.title).joined(separator: ", ")
    }
}

private extension OwnershipEvidence {
    var title: String {
        switch self {
        case .manualInclude: "manual include"
        case .primaryProcess: "primary process"
        case .executableInsideBundle: "inside application bundle"
        case .responsibleProcess: "responsible process"
        case .descendantOfPrimary: "process ancestry"
        case .relatedBundleIdentifier: "related bundle"
        case .nameSimilarity: "name similarity"
        }
    }
}
