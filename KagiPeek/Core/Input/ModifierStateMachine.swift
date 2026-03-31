import CoreGraphics
import Foundation

enum ModifierToken: String, CaseIterable {
    case cmd
    case opt
    case ctrl
    case shift

    static let ordered: [ModifierToken] = [.cmd, .opt, .ctrl, .shift]
}

struct ModifierStateMachine {
    private(set) var active: Set<ModifierToken> = []

    mutating func update(with flags: CGEventFlags) -> Bool {
        let next = Self.tokens(from: flags)
        let changed = next != active
        active = next
        return changed
    }

    func prefixTokens() -> [String] {
        ModifierToken.ordered.filter(active.contains).map(\.rawValue)
    }

    mutating func reset() {
        active.removeAll()
    }

    static func tokens(from flags: CGEventFlags) -> Set<ModifierToken> {
        var result: Set<ModifierToken> = []
        if flags.contains(.maskCommand) { result.insert(.cmd) }
        if flags.contains(.maskAlternate) { result.insert(.opt) }
        if flags.contains(.maskControl) { result.insert(.ctrl) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        return result
    }
}
