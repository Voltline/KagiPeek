import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum KeyMapper {
    static func token(from event: CGEvent) -> String? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch keyCode {
        case Int64(kVK_Escape):
            return "esc"
        case Int64(kVK_Tab):
            return "tab"
        case Int64(kVK_Space):
            return "space"
        case Int64(kVK_Return):
            return "enter"
        default:
            break
        }

        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else {
            return nil
        }

        let raw = String(utf16CodeUnits: chars, count: length)
        let lowered = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowered.isEmpty else {
            return nil
        }
        return lowered
    }
}
