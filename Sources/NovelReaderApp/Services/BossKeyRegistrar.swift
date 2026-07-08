import AppKit
import Carbon.HIToolbox
import Foundation

enum BossKeyRegistrationError: LocalizedError, Equatable {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            "快捷键不可用。"
        }
    }
}

@MainActor
protocol BossKeyRegistering: AnyObject {
    func register(shortcut: BossKeyShortcut, action: @escaping () -> Void) throws
    func unregister()
}

@MainActor
final class CarbonBossKeyRegistrar: BossKeyRegistering {
    static let shared = CarbonBossKeyRegistrar()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    private init() {
        installEventHandler()
    }

    func register(shortcut: BossKeyShortcut, action: @escaping () -> Void) throws {
        unregister()
        self.action = action

        var nextHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("NVRD"), id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &nextHotKeyRef
        )

        guard status == noErr else {
            self.action = nil
            throw BossKeyRegistrationError.registrationFailed(status)
        }

        hotKeyRef = nextHotKeyRef
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        action = nil
    }

    fileprivate func fire() {
        action?()
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonBossKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}

@MainActor
protocol WindowHiding {
    func hideReadingWindow()
}

@MainActor
struct AppKitWindowHider: WindowHiding {
    func hideReadingWindow() {
        NSApp.hide(nil)
    }
}

private let carbonBossKeyEventHandler: EventHandlerUPP = { _, _, _ in
    Task { @MainActor in
        CarbonBossKeyRegistrar.shared.fire()
    }
    return noErr
}

private func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
