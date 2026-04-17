import SwiftUI
import AppKit
import Carbon.HIToolbox

/// SwiftUI wrapper around an NSView that captures the next key+modifier combo
/// pressed while focused, and reports it back.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var combo: HotkeyCombo

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = { newCombo in
            self.combo = newCombo
        }
        view.currentCombo = combo
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.currentCombo = combo
        nsView.needsDisplay = true
    }

    final class RecorderView: NSView {
        var currentCombo: HotkeyCombo = .default
        var onCapture: ((HotkeyCombo) -> Void)?
        private var isRecording = false

        override var acceptsFirstResponder: Bool { true }
        override var wantsDefaultClipping: Bool { false }

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
        }

        required init?(coder: NSCoder) { super.init(coder: coder) }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isRecording = true
            needsDisplay = true
        }

        override func becomeFirstResponder() -> Bool {
            isRecording = true
            needsDisplay = true
            return super.becomeFirstResponder()
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            needsDisplay = true
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else { super.keyDown(with: event); return }
            // Ignore bare modifier-only taps; require at least one modifier + key.
            let mods = HotkeyCombo.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { NSSound.beep(); return }
            let combo = HotkeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
            currentCombo = combo
            onCapture?(combo)
            isRecording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let text = isRecording ? "Press new shortcut…" : currentCombo.displayString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let size = str.size()
            let point = NSPoint(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2
            )
            str.draw(at: point)
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: 180, height: 28)
        }
    }
}
