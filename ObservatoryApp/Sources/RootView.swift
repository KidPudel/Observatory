import AppKit
import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case now
    case sessions

    var id: Self { self }

    var title: String {
        switch self {
        case .now: "Now"
        case .sessions: "Tests"
        }
    }

    var systemImage: String {
        switch self {
        case .now: "gauge.with.dots.needle.67percent"
        case .sessions: "record.circle"
        }
    }

    var caption: String {
        switch self {
        case .now: "Live view of what your applications are using"
        case .sessions: "Create, revisit, and compare controlled tests"
        }
    }

    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .now: "1"
        case .sessions: "2"
        }
    }

}

enum EditorialPalette {
    static let lime = Color(red: 0.63, green: 0.70, blue: 0.45)
    static let gold = Color(red: 0.78, green: 0.63, blue: 0.34)
    static let blue = Color(red: 0.43, green: 0.55, blue: 0.62)
}

private struct WorkspaceInteractionSuppressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var workspaceInteractionSuppressed: Bool {
        get { self[WorkspaceInteractionSuppressedKey.self] }
        set { self[WorkspaceInteractionSuppressedKey.self] = newValue }
    }
}

private struct WorkspaceHoverModifier: ViewModifier {
    @Binding var isHovering: Bool
    @Environment(\.workspaceInteractionSuppressed) private var isSuppressed

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = isSuppressed ? false : hovering
            }
            .onChange(of: isSuppressed) { _, suppressed in
                if suppressed {
                    isHovering = false
                }
            }
    }
}

extension View {
    func workspaceHover(_ isHovering: Binding<Bool>) -> some View {
        modifier(WorkspaceHoverModifier(isHovering: isHovering))
    }
}

struct RootView: View {
    @State private var selection: AppDestination
    @StateObject private var nowViewModel: NowViewModel
    @StateObject private var sessionsViewModel: SessionsViewModel
    @StateObject private var historyViewModel: HistoryViewModel
    @StateObject private var focusEffectModality = FocusEffectModality()
    @FocusState private var pointerFocusSinkFocused: Bool
    @State private var initiallyShowsSavedResults: Bool
    @EnvironmentObject private var settingsPresentation: SettingsPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init() {
        let models = AppServices.makeRootModels()
        let storedDestination = UserDefaults.standard.string(
            forKey: AppPreferenceKeys.defaultDestination
        )
        let opensRetiredHistory = storedDestination == "history"
        if opensRetiredHistory {
            UserDefaults.standard.set(
                AppDestination.sessions.rawValue,
                forKey: AppPreferenceKeys.defaultDestination
            )
        }
        _selection = State(
            initialValue:
                opensRetiredHistory
                    ? .sessions
                    : (AppDestination(rawValue: storedDestination ?? "") ?? .now)
        )
        _initiallyShowsSavedResults = State(initialValue: opensRetiredHistory)
        _nowViewModel = StateObject(wrappedValue: models.now)
        _sessionsViewModel = StateObject(wrappedValue: models.sessions)
        _historyViewModel = StateObject(wrappedValue: models.history)
    }

    var body: some View {
        ZStack {
            AppCanvasBackground()

            Color.clear
                .frame(width: 1, height: 1)
                .focusable()
                .focusEffectDisabled()
                .focused($pointerFocusSinkFocused)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                GlobalNavigationBar(
                    selection: $selection,
                    settingsPresented: settingsPresentation.isPresented,
                    toggleSettings: settingsPresentation.toggle
                )
                    .padding(.top, 12)

                Group {
                    switch selection {
                    case .now:
                        NowView(model: nowViewModel) { application in
                            sessionsViewModel.prepareDraft(for: application)
                            selection = .sessions
                        }
                    case .sessions:
                        SessionsView(
                            model: sessionsViewModel,
                            historyModel: historyViewModel,
                            initiallyShowsSavedResults:
                                initiallyShowsSavedResults,
                            onInitialExpansionConsumed: {
                                initiallyShowsSavedResults = false
                            }
                        )
                    }
                }
                .id(selection)
                .transition(destinationTransition)
            }
            .environment(
                \.workspaceInteractionSuppressed,
                settingsPresentation.isPresented
            )
            .allowsHitTesting(!settingsPresentation.isPresented)
            .accessibilityHidden(settingsPresentation.isPresented)

            if settingsPresentation.isPresented {
                Button(action: settingsPresentation.dismiss) {
                    Color.black
                        .opacity(colorScheme == .dark ? 0.34 : 0.16)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
                .transition(.opacity)
                .zIndex(10)
            }

            if settingsPresentation.isPresented {
                ObservatorySettingsCard(dismiss: settingsPresentation.dismiss)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 56)
                    .transition(settingsTransition)
                    .zIndex(11)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .focusEffectDisabled(
            !focusEffectModality.showsKeyboardFocusEffects
        )
        .onAppear {
            focusEffectModality.start()
        }
        .onDisappear {
            focusEffectModality.stop()
        }
        .onChange(of: focusEffectModality.pointerFocusResetSequence) {
            pointerFocusSinkFocused = true
        }
        .onKeyPress { _ in
            pointerFocusSinkFocused = false
            focusEffectModality.showKeyboardFocusEffects()
            return .ignored
        }
        .animation(
            .easeOut(duration: reduceMotion ? 0.1 : 0.14),
            value: selection
        )
        .animation(settingsAnimation, value: settingsPresentation.isPresented)
    }

    private var destinationTransition: AnyTransition {
        .opacity
    }

    private var settingsTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .offset(x: 52, y: -42)
                .combined(with: .scale(scale: 0.90, anchor: .topTrailing))
                .combined(with: .opacity),
            removal: .offset(x: 32, y: -28)
                .combined(with: .scale(scale: 0.94, anchor: .topTrailing))
                .combined(with: .opacity)
        )
    }

    private var settingsAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.08)
    }
}

@MainActor
private final class FocusEffectModality: ObservableObject {
    @Published private(set) var showsKeyboardFocusEffects = false
    @Published private(set) var pointerFocusResetSequence = 0

    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }

        if let pointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] event in
                MainActor.assumeIsolated {
                    let targetsTextInput =
                        self?.eventTargetsTextInput(event) ?? false
                    self?.showsKeyboardFocusEffects = false
                    if !targetsTextInput {
                        Task { @MainActor in
                            self?.pointerFocusResetSequence += 1
                        }
                    }
                }
                return event
            }
        ) {
            monitors.append(pointerMonitor)
        }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }

    func showKeyboardFocusEffects() {
        showsKeyboardFocusEffects = true
    }

    private func eventTargetsTextInput(_ event: NSEvent) -> Bool {
        guard let window = event.window else { return false }

        let screenPoint = window.convertPoint(
            toScreen: event.locationInWindow
        )
        var element = window.accessibilityHitTest(screenPoint) as? NSObject

        for _ in 0..<6 {
            guard let current = element else { return false }

            let roleSelector = NSSelectorFromString("accessibilityRole")
            if current.responds(to: roleSelector),
               let role = current.value(forKey: "accessibilityRole") as? String,
               role == "AXTextField" || role == "AXTextArea" {
                return true
            }

            let parentSelector = NSSelectorFromString("accessibilityParent")
            guard current.responds(to: parentSelector) else {
                return false
            }
            element = current.value(forKey: "accessibilityParent") as? NSObject
        }

        return false
    }
}

private struct GlobalNavigationBar: View {
    @Binding var selection: AppDestination
    let settingsPresented: Bool
    let toggleSettings: () -> Void

    var body: some View {
        ZStack {
            FloatingTabBar(selection: $selection)

            HStack {
                Spacer()

                Button(action: toggleSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .rotationEffect(.degrees(settingsPresented ? 24 : 0))
                        .scaleEffect(settingsPresented ? 0.92 : 1)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(GlobalActionButtonStyle(isActive: settingsPresented))
                .accessibilityLabel(settingsPresented ? "Close Settings" : "Settings")
                .help(settingsPresented ? "Close Settings" : "Settings")
            }
        }
        .padding(.horizontal, 24)
        .animation(
            .spring(response: 0.28, dampingFraction: 0.68),
            value: settingsPresented
        )
    }
}

private struct GlobalActionButtonStyle: ButtonStyle {
    let isActive: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .primary : .secondary)
            .background(
                Color.primary.opacity(
                    configuration.isPressed
                        ? (colorScheme == .dark ? 0.12 : 0.09)
                        : (
                            isActive
                                ? (colorScheme == .dark ? 0.095 : 0.07)
                                : (colorScheme == .dark ? 0.055 : 0.035)
                        )
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(
                            colorSchemeContrast == .increased
                                ? (colorScheme == .dark ? 0.32 : 0.20)
                                : (colorScheme == .dark ? 0.18 : 0.09)
                        ),
                        lineWidth: 0.75
                    )
            }
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: AppDestination
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.workspaceInteractionSuppressed)
    private var workspaceInteractionSuppressed
    @FocusState private var focusedDestination: AppDestination?
    @State private var showsKeyboardFocus = false
    @State private var hoveredDestination: AppDestination?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppDestination.allCases) { destination in
                Button {
                    showsKeyboardFocus = false
                    selection = destination
                } label: {
                    Text(destination.title)
                        .font(
                            .system(
                                size: 14,
                                weight: selection == destination ? .semibold : .regular
                            )
                        )
                        .foregroundStyle(selection == destination ? .primary : .secondary)
                        .frame(width: 104, height: 38)
                        .contentShape(Rectangle())
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(tabFill(for: destination))
                        }
                        .overlay {
                            if showsKeyboardFocus && focusedDestination == destination {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(focusEdge, lineWidth: 1.5)
                            }
                        }
                }
                .buttonStyle(.plain)
                .focusable()
                .focusEffectDisabled()
                .focused($focusedDestination, equals: destination)
                .onHover { isHovering in
                    hoveredDestination =
                        isHovering && !workspaceInteractionSuppressed
                            ? destination
                            : nil
                }
                .onKeyPress(.tab) {
                    showsKeyboardFocus = true
                    return .ignored
                }
                .onKeyPress(keys: [.return, .space]) { _ in
                    showsKeyboardFocus = true
                    selection = destination
                    return .handled
                }
                .keyboardShortcut(
                    destination.keyboardShortcut,
                    modifiers: .command
                )
                .accessibilityLabel(destination.title)
                .accessibilityHint(destination.caption)
                .accessibilityAddTraits(
                    selection == destination ? [.isSelected] : []
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(containerFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(containerEdge, lineWidth: 0.75)
        }
        .shadow(
            color: colorScheme == .dark
                ? Color.black.opacity(0.20)
                : Color.black.opacity(0.055),
            radius: 10,
            y: 3
        )
        .animation(.easeOut(duration: 0.1), value: hoveredDestination)
        .animation(.easeOut(duration: 0.14), value: selection)
        .onChange(of: workspaceInteractionSuppressed) { _, suppressed in
            if suppressed {
                hoveredDestination = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Primary navigation")
    }

    private func tabFill(for destination: AppDestination) -> Color {
        if selection == destination {
            return Color.primary.opacity(colorScheme == .dark ? 0.095 : 0.07)
        }
        if hoveredDestination == destination {
            return Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.035)
        }
        return .clear
    }

    private var containerFill: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.123, blue: 0.119)
            : Color(red: 0.986, green: 0.982, blue: 0.973)
    }

    private var containerEdge: Color {
        Color.primary.opacity(
            colorSchemeContrast == .increased
                ? (colorScheme == .dark ? 0.32 : 0.20)
                : (colorScheme == .dark ? 0.18 : 0.09)
        )
    }

    private var focusEdge: Color {
        Color.primary.opacity(colorSchemeContrast == .increased ? 0.72 : 0.32)
    }
}

struct DestinationCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(Color.secondary.opacity(0.74))
            .lineSpacing(2)
    }
}

struct AppCanvasBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        canvas
            .ignoresSafeArea()
    }

    private var canvas: Color {
        colorScheme == .dark
            ? Color(red: 0.086, green: 0.084, blue: 0.080)
            : Color(red: 0.976, green: 0.971, blue: 0.960)
    }
}

struct FloatingPage<Content: View>: View {
    let title: String?
    let subtitle: String?
    let scrollsContent: Bool
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        scrollsContent: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollsContent = scrollsContent
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if scrollsContent {
            ScrollView {
                pageContent
            }
            .scrollIndicators(.hidden)
        } else {
            pageContent
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: title == nil ? 0 : 32) {
            if let title, let subtitle {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .tracking(-1.2)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: 980, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, title == nil ? 28 : 48)
        .padding(.bottom, scrollsContent ? 48 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FloatingEmptyState: View {
    let systemImage: String
    let eyebrow: String
    let accent: Color
    let title: String
    let message: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent)
                        .frame(width: 9, height: 9)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                        }
                        .accessibilityHidden(true)

                    Text(eyebrow)
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.045),
                    in: Capsule()
                )

                Spacer()

                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .light))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.035),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.07),
                                lineWidth: 0.75
                            )
                    }
            }

            Spacer(minLength: 56)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .tracking(-0.6)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .frame(maxWidth: 460, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    cardEdge,
                    lineWidth: 0.75
                )
        }
        .shadow(
            color: colorScheme == .dark
                ? Color.black.opacity(0.24)
                : Color.black.opacity(0.035),
            radius: 16,
            y: 4
        )
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.123, blue: 0.119)
            : Color(red: 0.945, green: 0.940, blue: 0.928)
    }

    private var cardEdge: Color {
        Color.primary.opacity(
            colorSchemeContrast == .increased
                ? (colorScheme == .dark ? 0.28 : 0.18)
                : (colorScheme == .dark ? 0.13 : 0.07)
        )
    }
}
