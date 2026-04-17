import XCTest
import Carbon.HIToolbox
@testable import KVTabFinder

final class HotkeyComboTests: XCTestCase {
    func testDefaultIsOptionTab() {
        let d = HotkeyCombo.default
        XCTAssertEqual(d.keyCode, UInt32(kVK_Tab))
        XCTAssertEqual(d.carbonModifiers, UInt32(optionKey))
        XCTAssertEqual(d.displayString, "⌥⇥")
    }

    func testRoundTrip() throws {
        let c = HotkeyCombo(
            keyCode: UInt32(kVK_Space),
            carbonModifiers: UInt32(cmdKey | optionKey | controlKey)
        )
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testDisplayStringOrderCtrlOptShiftCmd() {
        let c = HotkeyCombo(
            keyCode: UInt32(kVK_Space),
            carbonModifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey)
        )
        XCTAssertEqual(c.displayString, "⌃⌥⇧⌘Space")
    }

    func testNSEventModifierConversion() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        XCTAssertEqual(HotkeyCombo.carbonModifiers(from: flags),
                       UInt32(cmdKey | shiftKey))
    }
}
