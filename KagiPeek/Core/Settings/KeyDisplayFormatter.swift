import Foundation

enum KeyDisplayFormatter {
    static func render(keys: [String], style: AppSettings.KeyDisplayStyle) -> String {
        keys.map { display(token: $0, style: style) }
            .joined(separator: style == .symbols ? " " : " + ")
    }

    private static func display(token: String, style: AppSettings.KeyDisplayStyle) -> String {
        let value = token.lowercased()
        switch style {
        case .words:
            switch value {
            case "cmd": return "command"
            case "opt": return "option"
            case "ctrl": return "control"
            case "shift": return "shift"
            case "esc": return "escape"
            case "tab": return "tab"
            case "space": return "space"
            case "enter": return "enter"
            default: return value
            }
        case .symbols:
            switch value {
            case "cmd": return "⌘"
            case "opt": return "⌥"
            case "ctrl": return "⌃"
            case "shift": return "⇧"
            case "esc": return "esc"
            case "tab": return "tab"
            case "space": return "space"
            case "enter": return "enter"
            default: return value
            }
        }
    }
}
