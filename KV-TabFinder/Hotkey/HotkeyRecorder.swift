import SwiftUI
import AppKit
import Carbon.HIToolbox

/// SwiftUI wrapper around an NSView that captures the next key+modifier
/// combo pressed while focused, and reports it back.
///
/// Implementation mirrors KV-TextSniper's ShortcutRecorderField because
/// a simple `mouseDown` + `draw(_:)` variant did not reliably accept
/// first-responder when hosted inside an NSHostingController window
/// (clicks would bounce off the view, focus stayed on the window's
/// contentView, keyDown never reached the recorder).
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var combo: HotkeyCombo

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = { newCombo in
            self.combo = newCombo
        }
        view.display(combo: combo)
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.onCapture = { newCombo in
            self.combo = newCombo
        }
        nsView.display(combo: combo)
    }

    final class RecorderView: NSView {

        var onCapture: ((HotkeyCombo) -> Void)?

        private let label = NSTextField(labelWithString: "")
        private var isRecording = false {
            didSet { needsDisplay = true; updateLabel() }
        }
        private var currentCombo: HotkeyCombo = .default

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 6

            label.alignment = .center
            label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            label.textColor = .labelColor
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])

            let click = NSClickGestureRecognizer(target: self, action: #selector(activate))
            addGestureRecognizer(click)
        }

        // mouseDown fires immediately on press, well before
        // NSClickGestureRecognizer completes on mouseUp. Claim first
        // responder here so a key pressed right after the click isn't
        // dropped because isRecording is still false.
        override func mouseDown(with event: NSEvent) {
            if window?.firstResponder !== self {
                window?.makeFirstResponder(self)
            }
            // Don't call super to avoid the gesture recognizer fighting us.
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override var acceptsFirstResponder: Bool { true }

        override func becomeFirstResponder() -> Bool {
            isRecording = true
            Log.hotkey.notice("recorder becomeFirstResponder → isRecording=true")
            return super.becomeFirstResponder()
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            Log.hotkey.notice("recorder resignFirstResponder → isRecording=false")
            return super.resignFirstResponder()
        }

        func display(combo: HotkeyCombo) {
            currentCombo = combo
            updateLabel()
        }

        private func updateLabel() {
            if isRecording {
                label.stringValue = "Press keys…"
                label.textColor = .secondaryLabelColor
            } else {
                label.stringValue = currentCombo.displayString
                label.textColor = .labelColor
            }
        }

        @objc private func activate() {
            window?.makeFirstResponder(self)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let path = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                xRadius: 6, yRadius: 6
            )
            if isRecording {
                NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
                path.fill()
                NSColor.controlAccentColor.setStroke()
            } else {
                NSColor.controlBackgroundColor.setFill()
                path.fill()
                NSColor.separatorColor.setStroke()
            }
            path.lineWidth = 1
            path.stroke()
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: 180, height: 28)
        }

        override func keyDown(with event: NSEvent) {
            let code = Int(event.keyCode)
            let rawFlags = event.modifierFlags.rawValue
            Log.hotkey.notice("recorder keyDown code=\(code) flags=\(rawFlags, format: .hex) isRecording=\(self.isRecording)")

            guard isRecording else {
                super.keyDown(with: event)
                return
            }

            // Escape cancels recording.
            if event.keyCode == UInt16(kVK_Escape) {
                Log.hotkey.notice("recorder cancel by Esc")
                window?.makeFirstResponder(nil)
                return
            }

            let mods = HotkeyCombo.carbonModifiers(from: event.modifierFlags)
            // Require at least one modifier to avoid binding bare keys.
            guard mods != 0 else {
                Log.hotkey.notice("recorder reject — no modifier")
                NSSound.beep()
                return
            }

            let newCombo = HotkeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
            Log.hotkey.notice("recorder CAPTURED \(newCombo.displayString, privacy: .public)")
            currentCombo = newCombo
            onCapture?(newCombo)
            window?.makeFirstResponder(nil)
        }
    }
}
