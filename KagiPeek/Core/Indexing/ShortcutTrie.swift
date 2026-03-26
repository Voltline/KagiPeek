import Foundation

final class ShortcutTrieNode {
    var children: [String: ShortcutTrieNode] = [:]
    var shortcuts: [ShortcutItem] = []
}

final class ShortcutTrie {
    private let root = ShortcutTrieNode()

    func insert(_ shortcut: ShortcutItem) {
        var node = root
        for token in shortcut.keys.normalizedPrefixTokens() {
            if node.children[token] == nil {
                node.children[token] = ShortcutTrieNode()
            }
            node = node.children[token]!
        }
        node.shortcuts.append(shortcut)
    }

    func candidates(for prefix: [String]) -> [ShortcutItem] {
        guard let node = node(for: prefix.normalizedPrefixTokens()) else {
            return []
        }
        var results: [ShortcutItem] = []
        collect(from: node, into: &results)
        return results
    }

    private func node(for prefix: [String]) -> ShortcutTrieNode? {
        var node = root
        for token in prefix {
            guard let next = node.children[token] else {
                return nil
            }
            node = next
        }
        return node
    }

    private func collect(from node: ShortcutTrieNode, into results: inout [ShortcutItem]) {
        results.append(contentsOf: node.shortcuts)
        for child in node.children.values {
            collect(from: child, into: &results)
        }
    }
}
