import AppKit
import SwiftUI
import Observation

/// The menu bar status item and its dropdown panel.
///
/// Built on NSStatusItem rather than SwiftUI's MenuBarExtra because
/// MenuBarExtra has no way to be opened or closed from code, which we need
/// for notification clicks and for dismissing the dropdown after Start/Skip.
@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {
    private let timer: PomodoroTimer
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: DropdownPanel?
    /// The dropdown's SwiftUI content, kept alive between openings (so
    /// expanded sections stay expanded) but detached from the panel while
    /// it's closed, so the per-second countdown doesn't lay out a window
    /// nobody can see.
    private var content: NSView?
    private var outsideClickMonitor: Any?

    init(timer: PomodoroTimer) {
        self.timer = timer
        super.init()
        statusItem.autosaveName = "RezodoroStatusItem"
        if let button = statusItem.button {
            button.image = Self.icon
            button.imagePosition = .imageLeading
            button.toolTip = "Rezodoro"
            button.target = self
            button.action = #selector(togglePanel)
            // Open on mouse-down, like system menu bar items.
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
        observeTimer()
    }

    var isOpen: Bool { panel?.isVisible ?? false }

    @objc private func togglePanel() {
        isOpen ? close() : open()
    }

    func open() {
        guard !isOpen, let button = statusItem.button, let buttonWindow = button.window else { return }
        timer.checkForNewDay()

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = content ?? makeContent()

        // Hang the panel just below the status item, left-aligned with it
        // like a menu, but kept fully on screen. The window itself is a
        // fixed, transparent column reaching down to the bottom of the
        // screen; the visible glass card sits at its top and grows inside
        // it, so expanding a section never has to resize the window (which
        // made the content jump).
        let itemFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let width = PanelRoot.cardWidth + 2 * PanelRoot.margin
        let cardX = min(max(itemFrame.minX, visible.minX + 8), visible.maxX - PanelRoot.cardWidth - 8)
        let top = min(itemFrame.minY - 6, visible.maxY) + PanelRoot.margin
        panel.setFrame(NSRect(x: cardX - PanelRoot.margin, y: visible.minY, width: width, height: top - visible.minY), display: false)

        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)

        // Clicks in other apps never reach us as resignKey reliably for a
        // non-activating panel, so watch for them directly while open.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    func close() {
        guard isOpen else { return }
        panel?.orderOut(nil)
        panel?.contentView = nil
        statusItem.button?.highlight(false)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makeContent() -> NSView {
        let hosting = NSHostingView(rootView: PanelRoot(
            content: ContentView(timer: timer, dismiss: { [weak self] in self?.close() })
        ))
        // The window size is ours to set; don't let SwiftUI's size push back.
        hosting.sizingOptions = []
        content = hosting
        return hosting
    }

    private func makePanel() -> DropdownPanel {
        let panel = DropdownPanel()
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }
        return panel
    }

    // MARK: - Status item title

    /// Re-renders the status item whenever something it shows changes.
    /// Setting an AppKit title once a second is far cheaper than having
    /// SwiftUI re-render a label view into the menu bar.
    private func observeTimer() {
        withObservationTracking {
            updateStatusItem()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeTimer() }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        if timer.isRunning {
            button.attributedTitle = NSAttributedString(
                string: " " + timer.countdownText,
                attributes: [.font: Self.titleFont]
            )
        } else if !button.title.isEmpty {
            button.title = ""
        }
    }

    private static let titleFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    /// SF Symbols are drawn to sit on the same center line as system text,
    /// so the icon lines up with the countdown digits; as a template it
    /// adapts to light/dark menu bars.
    private static let icon: NSImage = {
        let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Rezodoro") ?? NSImage()
        image.isTemplate = true
        return image
    }()
}

/// The dropdown's SwiftUI root: the glass card pinned to the top of the
/// (transparent, larger) panel window. The glass is drawn by SwiftUI so its
/// shape animates together with the content when a section expands.
struct PanelRoot: View {
    static var cardWidth: CGFloat { 280 }
    /// Transparent room around the card for its shadow.
    static var margin: CGFloat { 16 }

    let content: ContentView

    var body: some View {
        content
            .frame(width: Self.cardWidth)
            .panelBackground()
            .padding(Self.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension View {
    /// Liquid Glass on macOS 26+, the blurred menu material before.
    @ViewBuilder
    func panelBackground() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        } else {
            background(.regularMaterial, in: .rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
    }
}

/// Borderless, non-activating panel (like a menu, it doesn't pull focus
/// away from the frontmost app) that can still become key so buttons and
/// the Return/Escape shortcuts work. Fully transparent outside the card,
/// so clicks there fall through to whatever is underneath.
final class DropdownPanel: NSPanel {
    var onCancel: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // the card draws its own
        level = .popUpMenu
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isReleasedWhenClosed = false
        isMovable = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
