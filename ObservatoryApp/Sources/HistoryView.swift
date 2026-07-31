import AppKit
import Combine
import Foundation
import ObservatoryDomain
import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var library = HistoryLibrary(tests: [])
    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published private(set) var openedTest: ControlledTestResult?
    @Published private(set) var openedResult: HistoricalApplicationResult?
    @Published private(set) var comparison: HistoricalComparison?
    @Published private(set) var isSelectingForComparison = false
    @Published private(set) var selectedResultIDs:
        Set<HistoricalApplicationResult.ID> = []
    @Published private(set) var errorMessage: String?
    @Published var searchText = ""

    private let engine: ControlledTestEngine

    init(engine: ControlledTestEngine) {
        self.engine = engine
    }

    var filteredResults: [HistoricalApplicationResult] {
        library.results(matching: searchText)
    }

    var selectedResults: [HistoricalApplicationResult] {
        library.results.filter { selectedResultIDs.contains($0.id) }
    }

    var hasOpenPresentation: Bool {
        openedTest != nil || openedResult != nil || comparison != nil
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let sessions = try await engine.recentSessions().filter {
                $0.kind == .controlledTest
                    && [.completed, .cancelled].contains($0.status)
            }
            var loadedTests: [ControlledTestResult] = []
            for session in sessions {
                if let result = try await engine.result(sessionID: session.id) {
                    loadedTests.append(result)
                }
            }
            library = HistoryLibrary(tests: loadedTests)
            pruneSelection()
        } catch {
            errorMessage = "Saved tests could not be loaded: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func open(_ test: ControlledTestResult) {
        openedResult = nil
        comparison = nil
        openedTest = test
    }

    func open(_ result: HistoricalApplicationResult) {
        openedTest = nil
        comparison = nil
        openedResult = result
    }

    func closePresentation() {
        openedTest = nil
        openedResult = nil
        comparison = nil
    }

    func leaveSavedResults() {
        closePresentation()
        isSelectingForComparison = false
        clearSelection()
    }

    func toggleComparisonSelectionMode() {
        isSelectingForComparison.toggle()
        if !isSelectingForComparison {
            clearSelection()
        }
    }

    func toggleSelection(_ result: HistoricalApplicationResult) {
        if selectedResultIDs.contains(result.id) {
            selectedResultIDs.remove(result.id)
        } else if selectedResultIDs.count < 4 {
            selectedResultIDs.insert(result.id)
        } else {
            errorMessage = "A comparison can include at most four results."
        }
    }

    func clearSelection() {
        selectedResultIDs = []
    }

    func toggleCombinedResults(in test: ControlledTestResult) {
        let combined = library.results.filter {
            $0.session.id == test.session.id && $0.scope == .combined
        }
        let combinedIDs = Set(combined.map(\.id))
        if combinedIDs.isSubset(of: selectedResultIDs) {
            selectedResultIDs.subtract(combinedIDs)
            return
        }

        let availableSlots = 4 - selectedResultIDs.count
        let additions = combined.filter {
            !selectedResultIDs.contains($0.id)
        }
        guard additions.count <= availableSlots else {
            errorMessage =
                "This test would exceed the four-result comparison limit."
            return
        }
        selectedResultIDs.formUnion(additions.map(\.id))
    }

    func compareSelection() {
        let candidate = HistoricalComparison(results: selectedResults)
        guard candidate.isValid else {
            errorMessage = "Select two to four application results to compare."
            return
        }
        openedTest = nil
        openedResult = nil
        comparison = candidate
    }

    func delete(_ session: MonitoringSession) {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await engine.deleteSavedSession(id: session.id)
                await load()
            } catch {
                errorMessage =
                    "The test could not be deleted completely: \(error.localizedDescription)"
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func pruneSelection() {
        let validIDs = Set(library.results.map(\.id))
        selectedResultIDs.formIntersection(validIDs)
        if let openedResult, !validIDs.contains(openedResult.id) {
            self.openedResult = nil
        }
        let validSessionIDs = Set(library.tests.map(\.session.id))
        if let openedTest, !validSessionIDs.contains(openedTest.session.id) {
            self.openedTest = nil
        }
        if let comparison,
           comparison.results.contains(where: { !validIDs.contains($0.id) }) {
            self.comparison = nil
        }
    }
}

struct SavedResultsLibrary: View {
    @ObservedObject var model: HistoryViewModel

    @State private var pendingDeletion: MonitoringSession?

    private var filteredSessionIDs: Set<UUID> {
        Set(model.filteredResults.map(\.session.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.errorMessage {
                SessionNotice(
                    message: error,
                    isError: true,
                    onDismiss: model.dismissError
                )
            }

            SessionSurface(padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    libraryHeader
                    searchField
                    if model.isSelectingForComparison,
                       !model.selectedResultIDs.isEmpty {
                        Divider()
                            .opacity(0.55)
                        comparisonTray
                    }
                }
            }

            libraryContent
        }
        .task {
            await model.load()
        }
        .confirmationDialog(
            "Delete \(pendingDeletion?.name ?? "this test")?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete test and all samples", role: .destructive) {
                if let session = pendingDeletion {
                    model.delete(session)
                }
                pendingDeletion = nil
            }
            Button("Keep test", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text(
                "This removes the test, every application and round result, raw samples, and its private summary folder. Other tests are not affected."
            )
        }
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Saved results")
                    .font(.system(size: 21, weight: .semibold))
                Text(
                    "\(model.library.tests.count) recorded \(model.library.tests.count == 1 ? "test" : "tests") · Open a complete test or one application result."
                )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Text(
                model.isSelectingForComparison
                    ? "Choose 2–4 results"
                    : "Browse mode"
            )
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            Button(
                model.isSelectingForComparison ? "Done selecting" : "Compare results",
                action: model.toggleComparisonSelectionMode
            )
            .buttonStyle(
                SessionActionButtonStyle(
                    primary: model.isSelectingForComparison
                )
            )
            .accessibilityValue(
                model.isSelectingForComparison ? "Selection mode" : "Browse mode"
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(
                "Search applications, tests, versions, modes, or notes",
                text: $model.searchText
            )
            .textFieldStyle(.plain)
            .accessibilityLabel("Search saved results")
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if model.isLoading && model.library.tests.isEmpty {
            SessionSurface {
                ProgressView("Loading saved results…")
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        } else if model.library.tests.isEmpty {
            SessionSurface {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    Text("No saved results yet")
                        .font(.system(size: 14, weight: .semibold))
                    Text(
                        "Complete a controlled test and its full result will appear here."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if model.filteredResults.isEmpty {
            SessionSurface {
                ContentUnavailableView.search(text: model.searchText)
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(
                    model.library.tests.filter {
                        filteredSessionIDs.contains($0.session.id)
                    },
                    id: \.session.id
                ) { test in
                    SavedResultsTestGroup(
                        test: test,
                        results: model.filteredResults.filter {
                            $0.session.id == test.session.id
                        },
                        selectedIDs: model.selectedResultIDs,
                        isSelecting: model.isSelectingForComparison,
                        onOpenTest: { model.open(test) },
                        onOpenResult: model.open,
                        onToggleResult: model.toggleSelection,
                        onToggleTest: { model.toggleCombinedResults(in: test) },
                        onDelete: { pendingDeletion = test.session }
                    )
                }
            }
        }
    }

    private var comparisonTray: some View {
        HStack(spacing: 12) {
            SessionEyebrow(
                title: "\(model.selectedResultIDs.count) OF 4 SELECTED",
                color: EditorialPalette.blue
            )
            Text(
                model.selectedResultIDs.count == 1
                    ? "Choose one more application result."
                    : "Ready to compare across measured time."
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            Spacer()
            Button("Clear", action: model.clearSelection)
                .buttonStyle(SessionActionButtonStyle())
            Button("Compare selected results", action: model.compareSelection)
                .buttonStyle(SessionActionButtonStyle(primary: true))
                .disabled(!(2...4).contains(model.selectedResultIDs.count))
        }
    }
}

struct CompactSavedResultsLibrary: View {
    @ObservedObject var model: HistoryViewModel
    let isOnLeadingSide: Bool
    let onMoveToOtherSide: () -> Void
    let onHide: () -> Void

    private var filteredSessionIDs: Set<UUID> {
        Set(model.filteredResults.map(\.session.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SessionSurface(padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Saved results")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(model.library.tests.count) tests")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Text(
                            model.isSelectingForComparison
                                ? "Choose 2–4"
                                : "Browse"
                        )
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: onMoveToOtherSide) {
                            Image(
                                systemName:
                                    isOnLeadingSide
                                        ? "chevron.right.2"
                                        : "chevron.left.2"
                            )
                            .frame(width: 18, height: 18)
                        }
                        .buttonStyle(SessionIconButtonStyle())
                        .help(
                            "Move Saved Results to the \(isOnLeadingSide ? "right" : "left")"
                        )
                        .accessibilityLabel(
                            "Move Saved Results to the \(isOnLeadingSide ? "right" : "left")"
                        )
                        Button(action: onHide) {
                            Image(systemName: "eye.slash")
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(SessionIconButtonStyle())
                        .help("Hide Saved Results")
                        .accessibilityLabel("Hide Saved Results")
                        Button(action: model.toggleComparisonSelectionMode) {
                            Image(
                                systemName:
                                    model.isSelectingForComparison
                                        ? "checkmark"
                                        : "arrow.left.arrow.right"
                            )
                            .frame(width: 18, height: 18)
                        }
                        .buttonStyle(SessionIconButtonStyle())
                        .help(
                            model.isSelectingForComparison
                                ? "Done selecting comparison results"
                                : "Select results to compare"
                        )
                        .accessibilityLabel(
                            model.isSelectingForComparison
                                ? "Done selecting comparison results"
                                : "Compare results"
                        )
                    }

                    compactSearchField

                    if model.isSelectingForComparison {
                        compactComparisonTray
                    }
                }
            }

            compactContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Concise saved results")
    }

    private var compactSearchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search results", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .accessibilityLabel("Search saved results")
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
        }
    }

    @ViewBuilder
    private var compactContent: some View {
        if model.filteredResults.isEmpty {
            SessionSurface(padding: 12) {
                Text(
                    model.library.tests.isEmpty
                        ? "No saved results yet."
                        : "No matching results."
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(
                    model.library.tests.filter {
                        filteredSessionIDs.contains($0.session.id)
                    },
                    id: \.session.id
                ) { test in
                    CompactSavedResultsTestGroup(
                        test: test,
                        results: model.filteredResults.filter {
                            $0.session.id == test.session.id
                        },
                        activeTestID: model.openedTest?.session.id,
                        activeResultID: model.openedResult?.id,
                        selectedIDs: model.selectedResultIDs,
                        isSelecting: model.isSelectingForComparison,
                        onOpenTest: { model.open(test) },
                        onOpenResult: model.open,
                        onToggleResult: model.toggleSelection
                    )
                }
            }
        }
    }

    private var compactComparisonTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .opacity(0.55)
            HStack(spacing: 6) {
                SessionEyebrow(
                    title: "\(model.selectedResultIDs.count) OF 4",
                    color: EditorialPalette.blue
                )
                Spacer()
                Button("Clear", action: model.clearSelection)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .disabled(model.selectedResultIDs.isEmpty)
            }
            Text(
                model.selectedResultIDs.count < 2
                    ? "Choose at least two results."
                    : "Ready to compare."
            )
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            Button("Compare selected", action: model.compareSelection)
                .buttonStyle(SessionActionButtonStyle(primary: true))
                .disabled(!(2...4).contains(model.selectedResultIDs.count))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CompactSavedResultsTestGroup: View {
    let test: ControlledTestResult
    let results: [HistoricalApplicationResult]
    let activeTestID: UUID?
    let activeResultID: HistoricalApplicationResult.ID?
    let selectedIDs: Set<HistoricalApplicationResult.ID>
    let isSelecting: Bool
    let onOpenTest: () -> Void
    let onOpenResult: (HistoricalApplicationResult) -> Void
    let onToggleResult: (HistoricalApplicationResult) -> Void

    var body: some View {
        SessionSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onOpenTest) {
                    HStack(spacing: 7) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(test.session.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Text(testMetadata)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 11)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .background(
                        Color.primary.opacity(
                            activeTestID == test.session.id ? 0.055 : 0
                        )
                    )
                }
                .buttonStyle(.plain)
                .focusable()
                .accessibilityLabel("Open complete test \(test.session.name)")

                Divider()
                    .opacity(0.48)

                ForEach(Array(results.enumerated()), id: \.element.id) {
                    index, result in
                    CompactSavedResultRow(
                        result: result,
                        isActive: activeResultID == result.id,
                        isSelected: selectedIDs.contains(result.id),
                        isSelecting: isSelecting,
                        onOpen: { onOpenResult(result) },
                        onToggle: { onToggleResult(result) }
                    )
                    if index < results.count - 1 {
                        Divider()
                            .padding(.leading, 42)
                            .opacity(0.38)
                    }
                }
            }
        }
    }

    private var testMetadata: String {
        let mode =
            test.session.controlledTestMode == .automaticForegroundIdle
                ? "Foreground idle"
                : "Manual guided"
        return "\(test.session.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(mode)"
    }
}

private struct CompactSavedResultRow: View {
    let result: HistoricalApplicationResult
    let isActive: Bool
    let isSelected: Bool
    let isSelecting: Bool
    let onOpen: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: isSelecting ? onToggle : onOpen) {
            HStack(spacing: 8) {
                Image(nsImage: applicationIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.application.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(result.scope.title)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(
                    systemName:
                        isSelecting
                            ? (isSelected ? "checkmark.circle.fill" : "circle")
                            : "chevron.right"
                )
                .font(.system(size: isSelecting ? 13 : 9, weight: .semibold))
                .foregroundStyle(
                    isSelected ? Color.primary : Color.secondary.opacity(0.52)
                )
                .frame(width: 18)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(
                Color.primary.opacity(
                    isActive || isSelected ? 0.055 : 0
                )
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(
                        isActive || isSelected
                            ? EditorialPalette.blue
                            : Color.clear
                    )
                    .frame(width: 2)
                    .padding(.vertical, 5)
            }
        }
        .buttonStyle(.plain)
        .focusable()
        .accessibilityLabel(
            isSelecting
                ? "\(isSelected ? "Remove" : "Add") \(result.application.displayName) \(result.scope.title) \(isSelected ? "from" : "to") comparison"
                : "Open \(result.application.displayName) \(result.scope.title)"
        )
    }

    private var applicationIcon: NSImage {
        NSWorkspace.shared.icon(
            forFile: result.application.identity.bundleURL.path
        )
    }
}

private struct SavedResultsTestGroup: View {
    let test: ControlledTestResult
    let results: [HistoricalApplicationResult]
    let selectedIDs: Set<HistoricalApplicationResult.ID>
    let isSelecting: Bool
    let onOpenTest: () -> Void
    let onOpenResult: (HistoricalApplicationResult) -> Void
    let onToggleResult: (HistoricalApplicationResult) -> Void
    let onToggleTest: () -> Void
    let onDelete: () -> Void

    private var combinedResults: [HistoricalApplicationResult] {
        results.filter { $0.scope == .combined }
    }

    private var allCombinedSelected: Bool {
        !combinedResults.isEmpty
            && combinedResults.allSatisfy { selectedIDs.contains($0.id) }
    }

    var body: some View {
        SessionSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Button(action: onOpenTest) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(test.session.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text("Open complete test")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(testMetadata)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(macOSVersionLabel(test.session.systemVersion))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .accessibilityLabel("Open complete test \(test.session.name)")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(SessionIconButtonStyle())
                    .foregroundStyle(.secondary)
                    .help("Delete \(test.session.name)")
                    .accessibilityLabel("Delete test")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if isSelecting && combinedResults.count > 1 {
                    Button(action: onToggleTest) {
                        Label(
                            allCombinedSelected
                                ? "Remove all application results"
                                : "Select all application results",
                            systemImage:
                                allCombinedSelected
                                    ? "checkmark.circle.fill"
                                    : "circle.dashed"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                Divider()
                    .opacity(0.55)

                ForEach(Array(results.enumerated()), id: \.element.id) {
                    index, result in
                    SavedResultRow(
                        result: result,
                        isSelected: selectedIDs.contains(result.id),
                        isSelecting: isSelecting,
                        onOpen: { onOpenResult(result) },
                        onToggle: { onToggleResult(result) }
                    )
                    if index < results.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                            .opacity(0.45)
                    }
                }
            }
        }
    }

    private var testMetadata: String {
        let mode =
            test.session.controlledTestMode == .automaticForegroundIdle
                ? "Foreground idle"
                : "Manual guided"
        return "\(test.session.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(mode)"
    }
}

private struct SavedResultRow: View {
    let result: HistoricalApplicationResult
    let isSelected: Bool
    let isSelecting: Bool
    let onOpen: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: isSelecting ? onToggle : onOpen) {
            HStack(spacing: 12) {
                Image(nsImage: applicationIcon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.application.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(appContext)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if !isSelecting {
                    metricStrip
                }

                Image(
                    systemName:
                        isSelecting
                            ? (isSelected ? "checkmark.circle.fill" : "circle")
                            : "chevron.right"
                )
                .font(.system(size: isSelecting ? 15 : 10, weight: .semibold))
                .foregroundStyle(
                    isSelected ? Color.primary : Color.secondary.opacity(0.55)
                )
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 66)
            .contentShape(Rectangle())
            .background(
                Color.primary.opacity(isSelected ? 0.06 : 0)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? EditorialPalette.blue : Color.clear)
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
        }
        .buttonStyle(.plain)
        .focusable()
        .accessibilityLabel(
            isSelecting
                ? "\(isSelected ? "Remove" : "Add") \(result.application.displayName) \(result.scope.title) \(isSelected ? "from" : "to") comparison"
                : "Open \(result.application.displayName) \(result.scope.title)"
        )
    }

    private var applicationIcon: NSImage {
        NSWorkspace.shared.icon(
            forFile: result.application.identity.bundleURL.path
        )
    }

    private var appContext: String {
        let version =
            result.application.version.map { "App version \($0)" }
                ?? "App version unknown"
        return "\(version) · \(result.scope.title)"
    }

    private var metricStrip: some View {
        HStack(spacing: 22) {
            HistoryCardMetric(
                label: "CPU AVG",
                value: result.summary.averageCPUCoreUsage.map {
                    String(format: "%.1f%%", $0 * 100)
                } ?? "—"
            )
            HistoryCardMetric(
                label: "MEMORY AVG",
                value: result.summary.averageMemoryBytes.map(
                    ByteCountFormatter.string
                ) ?? "—"
            )
            HistoryCardMetric(
                label: "DURATION",
                value: durationLabel(result.summary.measuredDuration)
            )
        }
    }
}

func macOSVersionLabel(_ rawValue: String) -> String {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.lowercased().hasPrefix("macos") {
        return trimmed
    }
    if trimmed.hasPrefix("Version ") {
        return "macOS \(trimmed.dropFirst("Version ".count))"
    }
    return "macOS \(trimmed)"
}

private struct RetiredHistoryView: View {
    @ObservedObject var model: HistoryViewModel
    let onOpenTests: () -> Void

    @State private var pendingDeletion: MonitoringSession?

    var body: some View {
        FloatingPage(
            title: "History",
            subtitle: "Return to preserved results and compare them across time."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let error = model.errorMessage {
                    SessionNotice(
                        message: error,
                        isError: true,
                        onDismiss: model.dismissError
                    )
                }
                content
            }
        }
        .task {
            await model.load()
        }
        .confirmationDialog(
            "Delete \(pendingDeletion?.name ?? "this test")?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete test and all samples", role: .destructive) {
                if let session = pendingDeletion {
                    model.delete(session)
                }
                pendingDeletion = nil
            }
            Button("Keep test", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text(
                "This removes the test, every application and round result, raw samples, and its private summary folder. Other tests are not affected."
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.library.tests.isEmpty {
            SessionSurface {
                ProgressView("Loading saved tests…")
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        } else if let comparison = model.comparison {
            HistoryComparisonPanel(
                comparison: comparison,
                onClose: model.closePresentation
            )
        } else if let result = model.openedResult {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(result.scope.title, systemImage: "square.stack.3d.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ResultPanel(
                    result: result.result,
                    onClose: model.closePresentation
                )
            }
        } else if model.library.tests.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                FloatingEmptyState(
                    systemImage: "clock.arrow.circlepath",
                    eyebrow: "SAVED RESULTS",
                    accent: EditorialPalette.blue,
                    title: "No recorded history",
                    message:
                        "Controlled tests preserve metrics, context, rounds, and one-second samples here. History only reopens data; it never starts monitoring."
                )
                Button("Open Tests", action: onOpenTests)
                    .buttonStyle(SessionActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
            }
        } else {
            HistoryLibraryView(
                model: model,
                onDelete: { pendingDeletion = $0 }
            )
        }
    }
}

private struct HistoryLibraryView: View {
    @ObservedObject var model: HistoryViewModel
    let onDelete: (MonitoringSession) -> Void

    private var filteredSessionIDs: Set<UUID> {
        Set(model.filteredResults.map(\.session.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionSurface(padding: 12) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField(
                            "Search applications, tests, versions, modes, or notes",
                            text: $model.searchText
                        )
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search saved results")

                        if !model.searchText.isEmpty {
                            Button {
                                model.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        Color.primary.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.primary.opacity(0.075),
                                lineWidth: 0.75
                            )
                    }

                    if !model.selectedResultIDs.isEmpty {
                        HStack(spacing: 10) {
                            SessionEyebrow(
                                title:
                                    "\(model.selectedResultIDs.count) SELECTED",
                                color: EditorialPalette.blue
                            )
                            Text(selectionGuidance)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear", action: model.clearSelection)
                                .buttonStyle(SessionActionButtonStyle())
                            Button("Compare", action: model.compareSelection)
                                .buttonStyle(
                                    SessionActionButtonStyle(primary: true)
                                )
                                .disabled(
                                    !(2...4).contains(
                                        model.selectedResultIDs.count
                                    )
                                )
                        }
                        .transition(.opacity)
                    }
                }
            }

            if model.filteredResults.isEmpty {
                SessionSurface {
                    ContentUnavailableView.search(text: model.searchText)
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
            } else {
                ForEach(
                    model.library.tests.filter {
                        filteredSessionIDs.contains($0.session.id)
                    },
                    id: \.session.id
                ) { test in
                    HistoryTestPanel(
                        test: test,
                        results: model.filteredResults.filter {
                            $0.session.id == test.session.id
                        },
                        selectedIDs: model.selectedResultIDs,
                        onOpen: model.open,
                        onToggle: model.toggleSelection,
                        onDelete: { onDelete(test.session) }
                    )
                }
            }
        }
    }

    private var selectionGuidance: String {
        model.selectedResultIDs.count == 1
            ? "Choose one more result to compare."
            : "Ready to compare across measured time."
    }
}

private struct HistoryTestPanel: View {
    let test: ControlledTestResult
    let results: [HistoricalApplicationResult]
    let selectedIDs: Set<HistoricalApplicationResult.ID>
    let onOpen: (HistoricalApplicationResult) -> Void
    let onToggle: (HistoricalApplicationResult) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        SessionSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(test.session.name)
                            .font(.system(size: 17, weight: .semibold))
                        Text(testMetadata)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(SessionIconButtonStyle())
                    .foregroundStyle(.secondary)
                    .opacity(isHovering ? 1 : 0.42)
                    .help("Delete \(test.session.name)")
                    .accessibilityLabel("Delete test")
                    .disabled(![.completed, .cancelled].contains(test.session.status))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, test.session.note.isEmpty ? 13 : 8)

                if !test.session.note.isEmpty {
                    Label(test.session.note, systemImage: "text.quote")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                Divider()
                    .opacity(0.55)

                ForEach(Array(results.enumerated()), id: \.element.id) {
                    index, result in
                    VStack(spacing: 0) {
                        HistoryResultCard(
                            result: result,
                            isSelected: selectedIDs.contains(result.id),
                            onOpen: { onOpen(result) },
                            onToggle: { onToggle(result) }
                        )
                        if index < results.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                                .opacity(0.45)
                        }
                    }
                }
            }
        }
        .workspaceHover($isHovering)
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }

    private var testMetadata: String {
        let mode =
            test.session.controlledTestMode == .automaticForegroundIdle
                ? "Foreground idle"
                : "Manual guided"
        return "\(test.session.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(mode) · \(macOSVersionLabel(test.session.systemVersion))"
    }
}

private struct HistoryResultCard: View {
    let result: HistoricalApplicationResult
    let isSelected: Bool
    let onOpen: () -> Void
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Image(nsImage: applicationIcon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.application.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(versionAndScope)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)
                    metricStrip

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .opacity(isHovering ? 1 : 0.45)
                        .padding(.leading, 4)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable()
            .accessibilityLabel(
                "Open \(result.application.displayName), \(versionAndScope)"
            )

            Button(action: onToggle) {
                Image(
                    systemName:
                        isSelected ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(
                    isSelected ? Color.primary : Color.secondary.opacity(0.55)
                )
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .focusable()
            .accessibilityLabel(
                isSelected ? "Remove from comparison" : "Add to comparison"
            )
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 66)
        .background(
            Color.primary.opacity(
                isSelected ? 0.06 : (isHovering ? 0.028 : 0)
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? EditorialPalette.blue : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
        .workspaceHover($isHovering)
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .accessibilityElement(children: .contain)
    }

    private var metricStrip: some View {
        HStack(spacing: 18) {
            HistoryCardMetric(
                label: "CPU AVG",
                value: result.summary.averageCPUCoreUsage.map {
                    String(format: "%.1f%%", $0 * 100)
                } ?? "—"
            )
            HistoryCardMetric(
                label: "MEMORY AVG",
                value: result.summary.averageMemoryBytes.map(
                    ByteCountFormatter.string
                ) ?? "—"
            )
            HistoryCardMetric(
                label: "DURATION",
                value: durationLabel(result.summary.measuredDuration)
            )
        }
    }

    private var applicationIcon: NSImage {
        NSWorkspace.shared.icon(
            forFile: result.application.identity.bundleURL.path
        )
    }

    private var versionAndScope: String {
        "\(result.application.version.map { "App version \($0)" } ?? "App version unknown") · \(result.scope.title)"
    }
}

private struct HistoryCardMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.25)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 58, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.capitalized)
        .accessibilityValue(value)
    }
}

struct HistoryComparisonPanel: View {
    let comparison: HistoricalComparison
    let onClose: () -> Void

    var body: some View {
        SessionSurface {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Result comparison")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                        Text(
                            "\(comparison.results.count) results aligned at measured elapsed time zero"
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Done", action: onClose)
                        .buttonStyle(SessionActionButtonStyle())
                }

                if !comparison.contextWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            "Recorded context differs",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.system(size: 13, weight: .semibold))
                        ForEach(comparison.contextWarnings, id: \.self) {
                            Text("• \($0)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.orange.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(Array(comparison.results.enumerated()), id: \.element.id) {
                        index, result in
                        ComparisonSummaryCard(result: result, index: index)
                    }
                }

                HistoryComparisonTimelinePanel(results: comparison.results)
            }
        }
    }
}

private struct ComparisonSummaryCard: View {
    let result: HistoricalApplicationResult
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Circle()
                    .fill(historySeriesColor(index))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(result.application.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(result.scope.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(result.session.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(contextLine)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(
                result.session.note.isEmpty
                    ? "No workload note"
                    : "Workload: \(result.session.note)"
            )
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            Text(macOSVersionLabel(result.session.systemVersion))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Divider()
            ComparisonValue(
                label: "Disk read",
                total: result.summary.diskReadBytes,
                rate: result.diskReadBytesPerSecond
            )
            ComparisonValue(
                label: "Disk write",
                total: result.summary.diskWriteBytes,
                rate: result.diskWriteBytesPerSecond
            )
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
    }

    private var contextLine: String {
        let version =
            result.application.version.map { "App version \($0)" }
                ?? "App version unknown"
        let mode =
            result.session.controlledTestMode == .automaticForegroundIdle
                ? "Foreground idle"
                : "Manual guided"
        return "\(version) · \(durationLabel(result.summary.measuredDuration)) · \(mode) · \(result.session.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct ComparisonValue: View {
    let label: String
    let total: Double?
    let rate: Double?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(total.map(ByteCountFormatter.string) ?? "—")
                .monospacedDigit()
            Text(rate.map { "\(ByteCountFormatter.string($0))/s" } ?? "—")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.system(size: 10))
    }
}

private extension ByteCountFormatter {
    static func string(_ value: Double) -> String {
        string(fromByteCount: Int64(value), countStyle: .file)
    }
}

private func durationLabel(_ duration: TimeInterval) -> String {
    if duration < 60 {
        return "\(Int(duration.rounded()))s"
    }
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
}

func historySeriesColor(_ index: Int) -> Color {
    let colors = [
        Color(red: 0.17, green: 0.69, blue: 0.78),
        Color(red: 0.58, green: 0.47, blue: 0.82),
        Color(red: 0.25, green: 0.70, blue: 0.55),
        Color(red: 0.91, green: 0.43, blue: 0.36)
    ]
    return colors[index % colors.count]
}
