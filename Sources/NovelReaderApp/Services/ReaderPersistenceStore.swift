import Foundation

struct ReaderPersistenceStore {
    private enum Key {
        static let fontSize = "NovelReader.settings.fontSize"
        static let lineHeight = "NovelReader.settings.lineHeight"
        static let theme = "NovelReader.settings.theme"
        static let paperColorHex = "NovelReader.settings.paperColorHex"
        static let inkColorHex = "NovelReader.settings.inkColorHex"
        static let accentColorHex = "NovelReader.settings.accentColorHex"
        static let fontFamily = "NovelReader.settings.fontFamily"
        static let emergencyBossCornerEnabled = "NovelReader.settings.emergencyBossCornerEnabled"
        static let bookshelfStyle = "NovelReader.settings.bookshelfStyle"
        static let customChapterPattern = "NovelReader.settings.customChapterPattern"
        static let readingMode = "NovelReader.settings.readingMode"
        static let bossKeyCode = "NovelReader.bossKey.keyCode"
        static let bossKeyModifiers = "NovelReader.bossKey.modifiers"
        static let recentFiles = "NovelReader.recentFiles"
        static let lastFile = "NovelReader.lastFile"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> ReadingSettings {
        var settings = ReadingSettings.default

        if defaults.object(forKey: Key.fontSize) != nil {
            settings.fontSize = defaults.double(forKey: Key.fontSize)
        }

        if defaults.object(forKey: Key.lineHeight) != nil {
            settings.lineHeight = defaults.double(forKey: Key.lineHeight)
        }

        if let themeRawValue = defaults.string(forKey: Key.theme),
           let theme = ReadingTheme(rawValue: themeRawValue) {
            settings.theme = theme
        }

        if let paperColorHex = defaults.string(forKey: Key.paperColorHex),
           paperColorHex.isEmpty == false {
            settings.paperColorHex = paperColorHex
        }

        if let inkColorHex = defaults.string(forKey: Key.inkColorHex),
           inkColorHex.isEmpty == false {
            settings.inkColorHex = inkColorHex
        }

        if let accentColorHex = defaults.string(forKey: Key.accentColorHex),
           accentColorHex.isEmpty == false {
            settings.accentColorHex = accentColorHex
        }

        if let fontFamily = defaults.string(forKey: Key.fontFamily),
           fontFamily.isEmpty == false {
            settings.fontFamily = fontFamily
        }

        if defaults.object(forKey: Key.emergencyBossCornerEnabled) != nil {
            settings.isEmergencyBossCornerEnabled = defaults.bool(forKey: Key.emergencyBossCornerEnabled)
        }

        if let bookshelfStyleRawValue = defaults.string(forKey: Key.bookshelfStyle),
           let bookshelfStyle = BookshelfStyle(rawValue: bookshelfStyleRawValue) {
            settings.bookshelfStyle = bookshelfStyle
        }

        if let customChapterPattern = defaults.string(forKey: Key.customChapterPattern),
           customChapterPattern.isEmpty == false {
            settings.customChapterPattern = customChapterPattern
        }

        if let readingModeRawValue = defaults.string(forKey: Key.readingMode),
           let readingMode = ReadingMode(rawValue: readingModeRawValue) {
            settings.readingMode = readingMode
        }

        return settings
    }

    func saveSettings(_ settings: ReadingSettings) {
        defaults.set(settings.fontSize, forKey: Key.fontSize)
        defaults.set(settings.lineHeight, forKey: Key.lineHeight)
        defaults.set(settings.theme.rawValue, forKey: Key.theme)
        defaults.set(settings.paperColorHex, forKey: Key.paperColorHex)
        defaults.set(settings.inkColorHex, forKey: Key.inkColorHex)
        defaults.set(settings.accentColorHex, forKey: Key.accentColorHex)
        defaults.set(settings.fontFamily, forKey: Key.fontFamily)
        defaults.set(settings.isEmergencyBossCornerEnabled, forKey: Key.emergencyBossCornerEnabled)
        defaults.set(settings.bookshelfStyle.rawValue, forKey: Key.bookshelfStyle)
        if let customChapterPattern = settings.customChapterPattern,
           customChapterPattern.isEmpty == false {
            defaults.set(customChapterPattern, forKey: Key.customChapterPattern)
        } else {
            defaults.removeObject(forKey: Key.customChapterPattern)
        }
        defaults.set(settings.readingMode.rawValue, forKey: Key.readingMode)
    }

    func loadBossKeyShortcut() -> BossKeyShortcut {
        guard defaults.object(forKey: Key.bossKeyCode) != nil,
              defaults.object(forKey: Key.bossKeyModifiers) != nil else {
            return .default
        }

        return BossKeyShortcut(
            keyCode: UInt32(defaults.integer(forKey: Key.bossKeyCode)),
            modifiers: UInt32(defaults.integer(forKey: Key.bossKeyModifiers))
        )
    }

    func saveBossKeyShortcut(_ shortcut: BossKeyShortcut) {
        defaults.set(Int(shortcut.keyCode), forKey: Key.bossKeyCode)
        defaults.set(Int(shortcut.modifiers), forKey: Key.bossKeyModifiers)
    }

    func loadRecentFileURLs() -> [URL] {
        defaults.stringArray(forKey: Key.recentFiles)?
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            ?? []
    }

    func addRecentFileURL(_ url: URL) {
        let existing = defaults.stringArray(forKey: Key.recentFiles) ?? []
        let path = url.path
        let next = ([path] + existing.filter { $0 != path }).prefix(50)
        defaults.set(Array(next), forKey: Key.recentFiles)
    }

    func loadLastFileURL() -> URL? {
        defaults.string(forKey: Key.lastFile).map(URL.init(fileURLWithPath:))
    }

    func saveLastFileURL(_ url: URL) {
        defaults.set(url.path, forKey: Key.lastFile)
    }

    func loadChapterIndex(for url: URL) -> Int {
        defaults.integer(forKey: chapterIndexKey(for: url))
    }

    func saveChapterIndex(_ index: Int, for url: URL) {
        defaults.set(index, forKey: chapterIndexKey(for: url))
    }

    func loadScrollOffset(for url: URL, chapter: Int) -> Double {
        defaults.double(forKey: scrollOffsetKey(for: url, chapter: chapter))
    }

    func saveScrollOffset(_ offset: Double, for url: URL, chapter: Int) {
        defaults.set(offset, forKey: scrollOffsetKey(for: url, chapter: chapter))
    }

    private func chapterIndexKey(for url: URL) -> String {
        let encodedPath = Data(url.path.utf8).base64EncodedString()
        return "NovelReader.chapterIndex.\(encodedPath)"
    }

    private func scrollOffsetKey(for url: URL, chapter: Int) -> String {
        let encodedPath = Data(url.path.utf8).base64EncodedString()
        return "NovelReader.scrollOffset.\(encodedPath).\(chapter)"
    }
}
