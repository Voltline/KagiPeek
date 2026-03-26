import AppKit
import Combine
import Foundation

@MainActor
final class KeyPrefixEngine: ObservableObject {
    @Published private(set) var currentPrefix: [String] = []
    @Published private(set) var candidates: [ShortcutItem] = []
    @Published private(set) var statusText: String = "闲置中"
    @Published private(set) var activeAppName: String = "未知应用"
    @Published private(set) var activeBundleIdentifier: String?

    var currentPrefixLabel: String {
        currentPrefix.isEmpty ? "(no modifier active)" : displayLabel(for: currentPrefix)
    }

    let settings: AppSettings
    private let listener = GlobalKeyListener()
    private let trie = ShortcutTrie()
    private lazy var overlay = OverlayPanelController(engine: self)
    private var overlayDisplayTask: Task<Void, Never>?
    private var isOverlayVisible = false
    private var usageFrequency: [String: Int]
    private var lastRecordedUsageToken: String?
    private var lastRecordedAt: Date?

    private let usageDefaultsKey = "shortcut.usage.frequency"

    init(settings: AppSettings) {
        self.settings = settings
        self.usageFrequency = UserDefaults.standard.dictionary(forKey: usageDefaultsKey) as? [String: Int] ?? [:]
        ShortcutStore.seedShortcuts.forEach { trie.insert($0) }

        listener.onSnapshot = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.handle(snapshot: snapshot)
            }
        }
    }

    func displayLabel(for keys: [String]) -> String {
        KeyDisplayFormatter.render(keys: keys, style: settings.keyDisplayStyle)
    }

    func visibleCandidates() -> [ShortcutItem] {
        let maxCount = settings.maxDisplayCount
        guard maxCount > 0 else {
            return candidates
        }
        return Array(candidates.prefix(maxCount))
    }

    func start() {
        do {
            try listener.start()
            statusText = "全局监听中 (辅助功能已授权)"
        } catch {
            statusText = error.localizedDescription
            print("[KagiPeek] 监听器启动失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener.stop()
        statusText = "已停止"
        cancelPendingOverlayShow()
        hideOverlay()
    }

    private func handle(snapshot: GlobalKeyEventSnapshot) {
        switch snapshot.type {
        case .modifierChanged:
            if snapshot.modifiers.isEmpty {
                currentPrefix = []
                candidates = []
                cancelPendingOverlayShow()
                hideOverlay()
            } else {
                update(prefix: snapshot.modifiers)
                scheduleOverlayShowIfNeeded()
            }
        case .keyDown:
            if snapshot.modifiers.isEmpty {
                return
            }
            let key = snapshot.key?.lowercased() ?? ""
            if key.isEmpty {
                update(prefix: snapshot.modifiers)
            } else {
                let exactKeys = snapshot.modifiers + [key]
                update(prefix: exactKeys)
                recordUsageIfExactMatch(for: exactKeys)
            }
            scheduleOverlayShowIfNeeded()
        case .keyUp:
            if snapshot.modifiers.isEmpty {
                currentPrefix = []
                candidates = []
                cancelPendingOverlayShow()
                hideOverlay()
            } else {
                update(prefix: snapshot.modifiers)
                if isOverlayVisible {
                    showOverlay()
                }
            }
        }
    }

    private func update(prefix: [String]) {
        refreshActiveApp()
        currentPrefix = prefix
        candidates = trie
            .candidates(for: prefix)
            .filter { $0.matches(bundleIdentifier: activeBundleIdentifier) }
            .sorted {
                let lhsUsage = effectiveUsageCount(for: $0)
                let rhsUsage = effectiveUsageCount(for: $1)
                if lhsUsage == rhsUsage {
                    return $0.keys.lexicographicallyPrecedes($1.keys)
                }
                switch settings.frequencySortOrder {
                case .descending:
                    return lhsUsage < rhsUsage
                case .ascending:
                    return lhsUsage > rhsUsage
                }
            }

        print("[KagiPeek] 前缀=\(prefix.joined(separator: "+"))")
        if candidates.isEmpty {
            print("[KagiPeek] 候选: []")
        } else {
            for candidate in candidates.prefix(10) {
                print("[KagiPeek] - \(candidate.keys.joined(separator: "+")) => \(candidate.desc)")
            }
        }
    }

    private func refreshActiveApp() {
        let app = NSWorkspace.shared.frontmostApplication
        activeAppName = app?.localizedName ?? "未知应用"
        activeBundleIdentifier = app?.bundleIdentifier
    }

    private func showOverlay() {
        isOverlayVisible = true
        overlay.show()
    }

    private func hideOverlay() {
        isOverlayVisible = false
        overlay.hide()
    }

    private func scheduleOverlayShowIfNeeded() {
        guard !isOverlayVisible else { return }
        guard overlayDisplayTask == nil else { return }

        overlayDisplayTask = Task { [weak self] in
            guard let self else { return }
            let delay = max(self.settings.overlayHoldDelaySeconds, 0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !self.currentPrefix.isEmpty else {
                    self.overlayDisplayTask = nil
                    return
                }
                self.showOverlay()
                self.overlayDisplayTask = nil
            }
        }
    }

    private func cancelPendingOverlayShow() {
        overlayDisplayTask?.cancel()
        overlayDisplayTask = nil
    }

    private func effectiveUsageCount(for shortcut: ShortcutItem) -> Int {
        shortcut.usageCount + (usageFrequency[shortcut.id] ?? 0)
    }

    private func recordUsageIfExactMatch(for keys: [String]) {
        let matched = trie
            .candidates(for: keys)
            .filter { $0.keys.normalizedPrefixTokens() == keys.normalizedPrefixTokens() }
            .filter { $0.matches(bundleIdentifier: activeBundleIdentifier) }

        guard !matched.isEmpty else { return }

        for shortcut in matched {
            let token = shortcut.id + "|" + keys.joined(separator: "+")
            if shouldSkipRepeatedUsage(for: token) {
                continue
            }
            usageFrequency[shortcut.id, default: 0] += 1
            persistUsageFrequency()
            lastRecordedUsageToken = token
            lastRecordedAt = Date()
        }
    }

    private func shouldSkipRepeatedUsage(for token: String) -> Bool {
        guard let lastRecordedUsageToken, let lastRecordedAt else {
            return false
        }
        let interval = Date().timeIntervalSince(lastRecordedAt)
        return token == lastRecordedUsageToken && interval < 0.35
    }

    private func persistUsageFrequency() {
        UserDefaults.standard.set(usageFrequency, forKey: usageDefaultsKey)
    }
}
