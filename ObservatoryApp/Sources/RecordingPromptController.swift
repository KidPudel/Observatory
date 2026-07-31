import AppKit
import Carbon.HIToolbox
import ObservatoryDomain
import SwiftUI

@MainActor
final class RecordingPromptController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<RecordingPromptContent>?

    fileprivate static let panelSize = NSSize(width: 336, height: 148)

    func update(
        state: ControlledTestEngineState,
        onStart: @escaping @MainActor () -> Void
    ) {
        guard let session = state.session,
              ![.completed, .cancelled, .failed].contains(session.status),
              !state.recoveryRequired,
              let round = state.currentRound
        else {
            close()
            return
        }

        let content = RecordingPromptContent(
            applicationName: round.application.displayName,
            roundNumber: round.roundNumber,
            totalRounds: session.controlledTestConfiguration?.roundCount ?? 1,
            mode: session.controlledTestMode ?? .manualGuided,
            status: round.status,
            remainingDuration: state.remainingDuration,
            onStart: onStart
        )
        if let panel, let hostingController {
            hostingController.rootView = content
            panel.orderFrontRegardless()
            return
        }

        let hosting = NSHostingController(rootView: content)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentViewController = hosting
        panel.setContentSize(Self.panelSize)
        positionForFirstAppearance(panel)
        panel.orderFrontRegardless()
        self.panel = panel
        hostingController = hosting
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
        hostingController = nil
    }

    private func positionForFirstAppearance(_ panel: NSPanel) {
        guard let screen = preferredScreen() else {
            panel.center()
            return
        }
        let safeFrame = screen.visibleFrame.insetBy(dx: 32, dy: 28)
        let size = panel.frame.size
        let desiredOrigin = NSPoint(
            x: safeFrame.midX - size.width / 2,
            y: safeFrame.maxY - size.height
        )
        let x = min(
            max(desiredOrigin.x, safeFrame.minX),
            max(safeFrame.minX, safeFrame.maxX - size.width)
        )
        let y = min(
            max(desiredOrigin.y, safeFrame.minY),
            max(safeFrame.minY, safeFrame.maxY - size.height)
        )
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func preferredScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSApp.keyWindow?.screen
            ?? NSApp.mainWindow?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first {
            $0.frame.contains(mouseLocation)
            }
            ?? NSScreen.screens.first
    }
}

private struct RecordingPromptContent: View {
    let applicationName: String
    let roundNumber: Int
    let totalRounds: Int
    let mode: ControlledTestMode
    let status: SessionRoundStatus
    let remainingDuration: TimeInterval?
    let onStart: @MainActor () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Circle()
                    .fill(status == .recording ? Color.red : EditorialPalette.gold)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Round \(roundNumber) of \(totalRounds)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Drag the prompt to move it")
            }

            Text(applicationName)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)

            if status == .pending && mode == .manualGuided {
                Button("Begin round", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
            } else if status == .activating {
                Text("Waiting for macOS to confirm the foreground application")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if let remainingDuration {
                Text("\(Int(ceil(remainingDuration))) seconds remaining")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
            }
        }
        .padding(18)
        .frame(
            width: RecordingPromptController.panelSize.width,
            height: RecordingPromptController.panelSize.height,
            alignment: .topLeading
        )
        .background(
            colorScheme == .dark
                ? Color(red: 0.105, green: 0.105, blue: 0.105)
                : Color(red: 0.955, green: 0.955, blue: 0.95),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(
                        contrast == .increased ? 0.24 : 0.11
                    ),
                    lineWidth: 0.75
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            WindowDragArea()
                .frame(height: 44)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Observatory recording prompt")
    }

    private var statusText: String {
        switch status {
        case .pending:
            "READY"
        case .activating:
            "ACTIVATING"
        case .warmingUp:
            "WARMING UP"
        case .recording:
            "RECORDING"
        case .completed:
            "COMPLETE"
        case .failed:
            "ACTIVATION FAILED"
        case .skipped:
            "SKIPPED"
        case .interrupted:
            "INTERRUPTED"
        case .cancelled:
            "CANCELLED"
        }
    }
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> PromptDragView {
        PromptDragView()
    }

    func updateNSView(_ nsView: PromptDragView, context: Context) {}
}

private final class PromptDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }
}

final class GlobalShortcutMonitor: @unchecked Sendable {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (@MainActor @Sendable () -> Void)?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let monitor = Unmanaged<GlobalShortcutMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                if let action = monitor.action {
                    Task { @MainActor in action() }
                }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    @discardableResult
    func configure(
        _ choice: GlobalShortcutChoice,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> Bool {
        unregister()
        self.action = action
        guard let definition = definition(for: choice) else { return true }
        let identifier = EventHotKeyID(
            signature: OSType(0x47554D53),
            id: 1
        )
        let status = RegisterEventHotKey(
            definition.keyCode,
            definition.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status != noErr {
            self.action = nil
            hotKey = nil
            return false
        }
        return true
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        action = nil
    }

    private func definition(
        for choice: GlobalShortcutChoice
    ) -> (keyCode: UInt32, modifiers: UInt32)? {
        switch choice {
        case .none:
            nil
        case .commandOptionSpace:
            (UInt32(kVK_Space), UInt32(cmdKey | optionKey))
        case .controlOptionReturn:
            (UInt32(kVK_Return), UInt32(controlKey | optionKey))
        }
    }
}
