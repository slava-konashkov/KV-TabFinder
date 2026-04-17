import AppKit
import Carbon.HIToolbox

/// Borderless floating panel that can become key (accepts keyboard input) but
/// keeps the previous app as the active application context for hotkeys etc.
///
/// Arrow keys (↑/↓), Enter and Escape are intercepted at the window level
/// via `sendEvent(_:)` — this runs before any responder chain dispatch, so
/// the embedded SwiftUI ScrollView never gets a chance to scroll on arrows
/// and the NSTextField can't "eat" Return/Escape depending on focus.
final class SearchPanel: NSPanel {

    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?

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

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // Ignore keys with modifier flags other than shift so text-field
            // shortcuts (Cmd+A, Cmd+C…) still work normally.
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .subtracting([.shift, .capsLock, .numericPad, .function])
            if mods.isEmpty {
                switch Int(event.keyCode) {
                case kVK_DownArrow:
                    onMoveDown?()
                    return
                case kVK_UpArrow:
                    onMoveUp?()
                    return
                case kVK_Return, kVK_ANSI_KeypadEnter:
                    onSubmit?()
                    return
                case kVK_Escape:
                    onEscape?()
                    return
                default:
                    break
                }
            }
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
