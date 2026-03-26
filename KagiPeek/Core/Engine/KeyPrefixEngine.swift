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
    @Published private(set) var accessibilityPermissionGranted: Bool = false

    private let listeningStatusText = "全局监听中 (辅助功能已授权)"
    private let gamePausedStatusText = "游戏应用前台，已暂停快捷键提示"
    private let gameKeywords = [
        "steam", "epic", "riot", "blizzard", "battle.net", "minecraft",
        "unity", "unreal", "dota", "csgo", "counter-strike", "valorant",
        "leagueoflegends", "genshin", "starcraft", "diablo", "overwatch", "game"
    ]

    var currentPrefixLabel: String {
        currentPrefix.isEmpty ? "(no modifier active)" : displayLabel(for: currentPrefix)
    }

    let settings: AppSettings
    private let listener = GlobalKeyListener()
    private let trie = ShortcutTrie()
    private lazy var overlay = OverlayPanelController(engine: self)
    private var overlayDisplayTask: Task<Void, Never>?
    private var permissionRetryTimer: Timer?
    private var appActivationObserver: NSObjectProtocol?
    private var isOverlayVisible = false
    private var isListenerRunning = false
    private var usageFrequency: [String: Int]
    private var lastRecordedUsageToken: String?
    private var lastRecordedAt: Date?

    private let usageDefaultsKey = "shortcut.usage.frequency"

    init(settings: AppSettings) {
        self.settings = settings
        self.usageFrequency = UserDefaults.standard.dictionary(forKey: usageDefaultsKey) as? [String: Int] ?? [:]
        self.accessibilityPermissionGranted = GlobalKeyListener.hasAccessibilityPermission()
        ShortcutStore.seedShortcuts.forEach { trie.insert($0) }
        setupActiveAppObserver()
        refreshActiveApp()

        listener.onSnapshot = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.handle(snapshot: snapshot)
            }
        }
    }

    deinit {
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
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
        startListener(promptForAccessibility: true)
    }

    func requestAccessibilityAuthorization() {
        accessibilityPermissionGranted = GlobalKeyListener.requestAccessibilityPermission()
        retryStartIfNeeded()
    }

    func openAccessibilitySettings() {
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func retryStartIfNeeded() {
        accessibilityPermissionGranted = GlobalKeyListener.hasAccessibilityPermission()
        guard !isListenerRunning else { return }
        if accessibilityPermissionGranted {
            startListener(promptForAccessibility: false)
        }
    }

    private func startListener(promptForAccessibility: Bool) {
        do {
            try listener.start(promptForAccessibility: promptForAccessibility)
            accessibilityPermissionGranted = true
            isListenerRunning = true
            stopPermissionRetryTimer()
            statusText = listeningStatusText
        } catch {
            accessibilityPermissionGranted = GlobalKeyListener.hasAccessibilityPermission()
            isListenerRunning = false
            statusText = error.localizedDescription
            print("[KagiPeek] 监听器启动失败: \(error.localizedDescription)")
            startPermissionRetryTimerIfNeeded()
        }
    }

    func stop() {
        listener.stop()
        isListenerRunning = false
        statusText = "已停止"
        cancelPendingOverlayShow()
        stopPermissionRetryTimer()
        hideOverlay()
    }

    private func startPermissionRetryTimerIfNeeded() {
        guard permissionRetryTimer == nil else { return }

        permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.retryStartIfNeeded()
            }
        }
    }

    private func stopPermissionRetryTimer() {
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
    }

    private func handle(snapshot: GlobalKeyEventSnapshot) {
        if isGameAppActive() {
            suppressOverlayAndCandidates()
            statusText = gamePausedStatusText
            return
        }

        if isListenerRunning && statusText == gamePausedStatusText {
            statusText = listeningStatusText
        }

        switch snapshot.type {
        case .modifierChanged:
            if snapshot.modifiers.isEmpty || isShiftOnly(snapshot.modifiers) {
                suppressOverlayAndCandidates()
            } else {
                update(prefix: snapshot.modifiers)
                scheduleOverlayShowIfNeeded()
            }
        case .keyDown:
            if snapshot.modifiers.isEmpty || isShiftOnly(snapshot.modifiers) {
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
            if snapshot.modifiers.isEmpty || isShiftOnly(snapshot.modifiers) {
                suppressOverlayAndCandidates()
            } else {
                update(prefix: snapshot.modifiers)
                if isOverlayVisible {
                    showOverlay()
                }
            }
        }
    }

    private func update(prefix: [String]) {
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

    private func setupActiveAppObserver() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshActiveApp()

                if self.isGameAppActive() {
                    self.suppressOverlayAndCandidates()
                    self.statusText = self.gamePausedStatusText
                } else if self.isListenerRunning {
                    self.statusText = self.listeningStatusText
                }
            }
        }
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

    private func suppressOverlayAndCandidates() {
        currentPrefix = []
        candidates = []
        cancelPendingOverlayShow()
        hideOverlay()
    }

    private func isShiftOnly(_ modifiers: [String]) -> Bool {
        modifiers.count == 1 && modifiers[0].lowercased() == "shift"
    }

    private func isGameAppActive() -> Bool {
        let bundle = activeBundleIdentifier?.lowercased() ?? ""
        let name = activeAppName.lowercased()
        return gameKeywords.contains { keyword in
            bundle.contains(keyword) || name.contains(keyword)
        }
    }
}
