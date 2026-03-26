import Foundation

enum ShortcutCategory: String, Hashable {
    case system
    case finder
    case textEditing
    case screenshot
    case browser

    var label: String {
        switch self {
        case .system:
            return "系统"
        case .finder:
            return "Finder"
        case .textEditing:
            return "文本"
        case .screenshot:
            return "截图"
        case .browser:
            return "浏览器"
        }
    }
}

struct ShortcutItem: Hashable, Identifiable {
    let keys: [String]
    let desc: String
    var usageCount: Int = 0
    var category: ShortcutCategory = .system
    var appScopes: [String] = []

    var id: String {
        keys.joined(separator: "+") + "::" + desc + "::" + category.rawValue + "::" + appScopes.joined(separator: ",")
    }

    func matches(bundleIdentifier: String?) -> Bool {
        guard !appScopes.isEmpty else {
            return true
        }
        guard let bundleIdentifier else {
            return false
        }
        return appScopes.contains(bundleIdentifier)
    }
}

extension Array where Element == String {
    func normalizedPrefixTokens() -> [String] {
        self.map { $0.lowercased() }
    }
}
