import Foundation

@MainActor
final class BossKeyController: ObservableObject {
    @Published private(set) var shortcut: BossKeyShortcut
    @Published var message: String?
    @Published var isRecording = false

    private let registrar: BossKeyRegistering
    private let persistence: ReaderPersistenceStore
    private let windowHider: WindowHiding

    init(
        registrar: BossKeyRegistering,
        persistence: ReaderPersistenceStore,
        windowHider: WindowHiding
    ) {
        self.registrar = registrar
        self.persistence = persistence
        self.windowHider = windowHider
        shortcut = persistence.loadBossKeyShortcut()
        registerCurrent()
    }

    func startRecording() {
        isRecording = true
        message = "请按快捷键。"
    }

    func exitRecording() {
        isRecording = false
    }

    func updateShortcut(_ shortcut: BossKeyShortcut) {
        guard shortcut.modifiers != 0 else {
            message = "需使用组合键。"
            return
        }

        do {
            try register(shortcut)
            self.shortcut = shortcut
            persistence.saveBossKeyShortcut(shortcut)
            exitRecording()
            message = "已设置。"
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "快捷键不可用。"
            try? register(self.shortcut)
        }
    }

    func activate() {
        windowHider.hideReadingWindow()
    }

    func shutdown() {
        registrar.unregister()
    }

    private func registerCurrent() {
        do {
            try register(shortcut)
            message = nil
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "快捷键不可用。"
        }
    }

    private func register(_ shortcut: BossKeyShortcut) throws {
        try registrar.register(shortcut: shortcut) { [weak self] in
            self?.activate()
        }
    }
}
