import AppKit

/// Borderless floating panel that can become key (accepts keyboard input) but
/// keeps the previous app as the active application context for hotkeys etc.
final class SearchPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .mainMenu + 2
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
