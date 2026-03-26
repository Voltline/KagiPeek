import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    enum FrequencySortOrder: String, CaseIterable, Identifiable {
        case descending
        case ascending

        var id: String { rawValue }

        var title: String {
            switch self {
            case .descending:
                return "倒排（低频优先）"
            case .ascending:
                return "正排（高频优先）"
            }
        }
    }

    enum KeyDisplayStyle: String, CaseIterable, Identifiable {
        case words
        case symbols

        var id: String { rawValue }

        var title: String {
            switch self {
            case .words:
                return "文字 (command)"
            case .symbols:
                return "图标 (⌘)"
            }
        }
    }

    @Published var overlayHoldDelaySeconds: Double
    @Published var launchAtLoginEnabled: Bool
    @Published var keyDisplayStyle: KeyDisplayStyle
    @Published var frequencySortOrder: FrequencySortOrder
    @Published var maxDisplayCount: Int
    @Published private(set) var launchAtLoginMessage: String = ""

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let overlayHoldDelaySeconds = "settings.overlayHoldDelaySeconds"
        static let launchAtLoginEnabled = "settings.launchAtLoginEnabled"
        static let keyDisplayStyle = "settings.keyDisplayStyle"
        static let frequencySortOrder = "settings.frequencySortOrder"
        static let maxDisplayCount = "settings.maxDisplayCount"
    }

    init() {
        let savedDelay = defaults.double(forKey: Keys.overlayHoldDelaySeconds)
        overlayHoldDelaySeconds = savedDelay > 0 ? savedDelay : 0.5

        if let savedStyleRaw = defaults.string(forKey: Keys.keyDisplayStyle),
           let savedStyle = KeyDisplayStyle(rawValue: savedStyleRaw) {
            keyDisplayStyle = savedStyle
        } else {
            keyDisplayStyle = .symbols
        }

        if let savedSortRaw = defaults.string(forKey: Keys.frequencySortOrder),
           let savedSortOrder = FrequencySortOrder(rawValue: savedSortRaw) {
            frequencySortOrder = savedSortOrder
        } else {
            frequencySortOrder = .descending
        }

        let savedMaxCount = defaults.integer(forKey: Keys.maxDisplayCount)
        maxDisplayCount = savedMaxCount > 0 ? savedMaxCount : 30

        if #available(macOS 13.0, *) {
            launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        } else {
            launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
        }

        bindPersistence()
    }

    private func bindPersistence() {
        $overlayHoldDelaySeconds
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: Keys.overlayHoldDelaySeconds)
            }
            .store(in: &cancellables)

        $keyDisplayStyle
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value.rawValue, forKey: Keys.keyDisplayStyle)
            }
            .store(in: &cancellables)

        $frequencySortOrder
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value.rawValue, forKey: Keys.frequencySortOrder)
            }
            .store(in: &cancellables)

        $maxDisplayCount
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: Keys.maxDisplayCount)
            }
            .store(in: &cancellables)

        $launchAtLoginEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.defaults.set(enabled, forKey: Keys.launchAtLoginEnabled)
                self?.updateLaunchAtLogin(enabled: enabled)
            }
            .store(in: &cancellables)
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    launchAtLoginMessage = "开机自启动已开启"
                } else {
                    try SMAppService.mainApp.unregister()
                    launchAtLoginMessage = "开机自启动已关闭"
                }
            } catch {
                launchAtLoginMessage = "开机自启动设置失败: \(error.localizedDescription)"
            }
        } else {
            launchAtLoginMessage = "当前系统版本不支持该方式的开机自启动设置"
        }
    }
}
