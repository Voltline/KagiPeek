import ApplicationServices
import CoreGraphics
import Foundation

enum GlobalKeyEventType {
    case modifierChanged
    case keyDown
    case keyUp
}

struct GlobalKeyEventSnapshot {
    let modifiers: [String]
    let key: String?
    let type: GlobalKeyEventType
}

enum GlobalKeyListenerError: LocalizedError {
    case accessibilityPermissionDenied
    case eventTapCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "需要辅助功能权限用于监听全局按键"
        case .eventTapCreationFailed:
            return "无法获取按键点击事件"
        }
    }
}

final class GlobalKeyListener {
    var onSnapshot: ((GlobalKeyEventSnapshot) -> Void)?
    var onInterruption: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifierState = ModifierStateMachine()

    deinit {
        stop()
    }

    func start(promptForAccessibility: Bool = true) throws {
        let trusted = promptForAccessibility
            ? Self.requestAccessibilityPermission()
            : Self.hasAccessibilityPermission()
        guard trusted else {
            throw GlobalKeyListenerError.accessibilityPermissionDenied
        }

        if eventTap != nil {
            return
        }

        let events: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let listener = Unmanaged<GlobalKeyListener>.fromOpaque(userInfo).takeUnretainedValue()
            listener.handle(eventType: eventType, event: event)
            return Unmanaged.passUnretained(event)
        }

        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: events,
            callback: callback,
            userInfo: opaqueSelf
        ) else {
            throw GlobalKeyListenerError.eventTapCreationFailed
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        modifierState.reset()
    }

    private func handle(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .flagsChanged:
            let changed = modifierState.update(with: event.flags)
            if changed {
                emit(.modifierChanged, key: nil)
            }
        case .keyDown:
            emit(.keyDown, key: KeyMapper.token(from: event))
        case .keyUp:
            emit(.keyUp, key: KeyMapper.token(from: event))
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            modifierState.reset()
            onInterruption?()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
    }

    private func emit(_ type: GlobalKeyEventType, key: String?) {
        let snapshot = GlobalKeyEventSnapshot(
            modifiers: modifierState.prefixTokens(),
            key: key,
            type: type
        )
        onSnapshot?(snapshot)
    }

    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }
}
