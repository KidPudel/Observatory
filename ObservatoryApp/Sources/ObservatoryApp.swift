import AppKit
import SwiftUI

@main
struct ObservatoryApp: App {
    @StateObject private var settingsPresentation = SettingsPresentation()

    init() {
        AppAppearance.stored.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settingsPresentation)
        }
        .defaultSize(width: 980, height: 680)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            ObservatorySettingsCommands(presentation: settingsPresentation)
        }
    }
}

@MainActor
final class SettingsPresentation: ObservableObject {
    @Published private(set) var isPresented = false

    func toggle() {
        isPresented.toggle()
    }

    func dismiss() {
        isPresented = false
    }
}

private struct ObservatorySettingsCommands: Commands {
    let presentation: SettingsPresentation

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                presentation.toggle()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

enum AppPreferenceKeys {
    static let appearance = "app.appearance"
    static let defaultDestination = "app.defaultDestination"
    static let savedResultsPanelSide = "tests.savedResultsPanelSide"
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    static var stored: AppAppearance {
        let storedValue = UserDefaults.standard.string(
            forKey: AppPreferenceKeys.appearance
        )
        return AppAppearance(rawValue: storedValue ?? "") ?? .system
    }

    @MainActor
    func apply() {
        let appearance: NSAppearance?
        switch self {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }

        NSApplication.shared.appearance = appearance
        for window in NSApplication.shared.windows {
            window.appearance = appearance
            window.contentView?.needsDisplay = true
        }
    }
}

struct ObservatorySettingsCard: View {
    let dismiss: () -> Void

    @AppStorage(AppPreferenceKeys.appearance)
    private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppPreferenceKeys.defaultDestination)
    private var defaultDestination = AppDestination.now.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 38, height: 38)
                    .background(
                        Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.045),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(panelEdge, lineWidth: 0.75)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .tracking(-0.7)

                    Text("Choose how Observatory looks and where each new launch begins.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                SummonedCloseButton(action: dismiss)
            }

            VStack(spacing: 0) {
                preferenceSection(
                    title: "Theme",
                    detail: "Follow macOS or keep Observatory in one appearance.",
                    selection: $appearance,
                    options: AppAppearance.allCases.map {
                        SettingsOption(
                            id: $0.rawValue,
                            title: $0.title,
                            systemImage: $0.systemImage
                        )
                    },
                    onSelection: { value in
                        (AppAppearance(rawValue: value) ?? .system).apply()
                    }
                )

                Divider()
                    .padding(.horizontal, 20)

                preferenceSection(
                    title: "Default view",
                    detail: "Open this destination when Observatory launches.",
                    selection: $defaultDestination,
                    options: AppDestination.allCases.map {
                        SettingsOption(
                            id: $0.rawValue,
                            title: $0.title,
                            systemImage: $0.systemImage
                        )
                    }
                )
            }
            .background(panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(panelEdge, lineWidth: 0.75)
            }

            HStack(spacing: 8) {
                Label("Metrics stay on this Mac", systemImage: "lock")
                    .accessibilityLabel("Privacy: metrics stay on this Mac")

                Spacer()

                Text(versionLabel)
                    .monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
        }
        .padding(28)
        .frame(width: 620)
        .background(settingsCanvas, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(outerEdge, lineWidth: 0.75)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.15),
            radius: 30,
            y: 12
        )
        .onExitCommand(perform: dismiss)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func preferenceSection(
        title: String,
        detail: String,
        selection: Binding<String>,
        options: [SettingsOption],
        onSelection: ((String) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(options) { option in
                    SettingsOptionButton(
                        option: option,
                        isSelected: selection.wrappedValue == option.id
                    ) {
                        selection.wrappedValue = option.id
                        onSelection?(option.id)
                    }
                }
            }
            .padding(5)
            .background(
                Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.035),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.065),
                        lineWidth: 0.75
                    )
            }
        }
        .padding(20)
    }

    private var panelFill: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.123, blue: 0.119)
            : Color(red: 0.958, green: 0.953, blue: 0.942)
    }

    private var settingsCanvas: Color {
        colorScheme == .dark
            ? Color(red: 0.086, green: 0.084, blue: 0.080)
            : Color(red: 0.976, green: 0.971, blue: 0.960)
    }

    private var versionLabel: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "Development"
        let build =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String
        return build.map { "Observatory \(version) (\($0))" }
            ?? "Observatory \(version)"
    }

    private var panelEdge: Color {
        Color.primary.opacity(
            colorSchemeContrast == .increased
                ? (colorScheme == .dark ? 0.28 : 0.18)
                : (colorScheme == .dark ? 0.13 : 0.07)
        )
    }

    private var outerEdge: Color {
        Color.primary.opacity(
            colorSchemeContrast == .increased
                ? (colorScheme == .dark ? 0.38 : 0.24)
                : (colorScheme == .dark ? 0.20 : 0.10)
        )
    }
}

private struct SummonedCloseButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .rotationEffect(.degrees(isHovered ? 90 : 0))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(SummonedCloseButtonStyle(isFocused: isFocused))
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .onAppear { isFocused = true }
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isHovered)
        .accessibilityLabel("Close Settings")
        .help("Close Settings")
    }

    private struct SummonedCloseButtonStyle: ButtonStyle {
        let isFocused: Bool

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.colorSchemeContrast) private var colorSchemeContrast

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(configuration.isPressed ? .primary : .secondary)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .background(
                    Color.primary.opacity(
                        configuration.isPressed
                            ? (colorScheme == .dark ? 0.14 : 0.10)
                            : (colorScheme == .dark ? 0.07 : 0.045)
                    ),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(
                                isFocused
                                    ? (colorSchemeContrast == .increased ? 0.7 : 0.36)
                                    : (colorScheme == .dark ? 0.16 : 0.08)
                            ),
                            lineWidth: isFocused ? 1.5 : 0.75
                        )
                }
                .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
        }
    }
}

private struct SettingsOption: Identifiable {
    let id: String
    let title: String
    let systemImage: String
}

private struct SettingsOptionButton: View {
    let option: SettingsOption
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                    .scaleEffect(isSelected ? 1.08 : 1)
                    .rotationEffect(.degrees(isSelected ? 0 : -5))

                Text(option.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

                Spacer(minLength: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.55)
                    .rotationEffect(.degrees(isSelected ? 0 : -18))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                optionFill,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(
                            isSelected
                                ? (colorScheme == .dark ? 0.16 : 0.09)
                                : 0
                        ),
                        lineWidth: 0.75
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .animation(.spring(response: 0.26, dampingFraction: 0.68), value: isSelected)
    }

    private var optionFill: Color {
        if isSelected {
            return Color.primary.opacity(colorScheme == .dark ? 0.105 : 0.075)
        }
        if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.052 : 0.035)
        }
        return .clear
    }
}
