import Carbon.HIToolbox
import AppKit

/// Registers a global hotkey via Carbon. Works in Mac App Store sandbox
/// and does not require Accessibility permission.
final class GlobalHotkey {
    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    deinit { unregister() }

    /// Register (or re-register) the hotkey. Any previous registration is removed first.
    @discardableResult
    func register(combo: HotkeyCombo, onPress: @escaping () -> Void) -> Bool {
        unregister()
        callback = onPress

        let hotKeyID = EventHotKeyID(signature: 0x54424646 /* 'TBFF' */, id: 1)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let instance = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { instance.callback?() }
                return noErr
            },
            1, &spec, selfPtr, &handlerRef
        )
        guard installStatus == noErr else {
            handlerRef = nil
            return false
        }

        let regStatus = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if regStatus != noErr {
            if let h = handlerRef { RemoveEventHandler(h) }
            handlerRef = nil
            hotKeyRef = nil
            return false
        }
        return true
    }

    func unregister() {
        if let r = hotKeyRef {
            UnregisterEventHotKey(r)
            hotKeyRef = nil
        }
        if let h = handlerRef {
            RemoveEventHandler(h)
            handlerRef = nil
        }
        callback = nil
    }
}
