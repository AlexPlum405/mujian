import Carbon.HIToolbox
import Foundation
import Testing
@testable import NovelReaderApp

@MainActor
struct ReaderModelTests {
    @Test func registersLocalBookOnOpen() async throws {
        let repository = InMemoryBookRepository()
        let model = makeModel(bookRepository: repository)
        let url = try temporaryFile(contents: "第一章\n正文")

        await model.loadTextFile(from: url)

        #expect(model.books.count == 1)
        let book = model.books.first
        #expect(book?.title == "novel.txt")
        #expect(book?.origin == .local(url))
    }

    @Test func deletesBookFromShelf() async throws {
        let repository = InMemoryBookRepository()
        let model = makeModel(bookRepository: repository)
        let url = try temporaryFile(contents: "第一章\n正文")

        await model.loadTextFile(from: url)
        #expect(model.books.count == 1)

        let bookId = model.books.first!.id
        model.deleteBook(id: bookId)

        #expect(model.books.count == 0)
        #expect(repository.loadAllBooks().isEmpty)
    }

    @Test func savesAndRestoresReadPosition() async throws {
        let repository = InMemoryBookRepository()
        let model = makeModel(bookRepository: repository)
        let url = try temporaryFile(contents: "第一章\n正文")

        await model.loadTextFile(from: url)
        let bookId = model.books.first!.id

        model.saveScrollOffset(120.5)

        let saved = repository.loadReadPosition(for: bookId)
        #expect(saved?.scrollOffset == 120.5)
    }

    @Test func accumulatesReadingSeconds() async throws {
        let repository = InMemoryBookRepository()
        let model = makeModel(bookRepository: repository)
        let url = try temporaryFile(contents: "第一章\n正文")

        await model.loadTextFile(from: url)
        let bookId = model.books.first!.id

        model.addReadingSeconds(30)
        model.addReadingSeconds(15)

        #expect(repository.loadReadingSeconds(for: bookId) == 45)
    }

    @Test func migratesLegacyRecentFilesToBooks() throws {
        let defaults = isolatedDefaults()
        let url = try temporaryFile(contents: "第一章\n正文")
        defaults.set([url.path], forKey: "NovelReader.recentFiles")

        let repository = InMemoryBookRepository()
        let model = makeModel(defaults: defaults, bookRepository: repository)

        #expect(model.books.count == 1)
        #expect(model.books.first?.title == "novel.txt")
        #expect(model.books.first?.origin == .local(url))
    }

    @Test func appliesThemePresetToCurrentAppearance() {
        let model = makeModel()
        let preset = ThemePreset(
            name: "我的主题", baseTheme: .sepia,
            paperColorHex: "#E9DCC7", inkColorHex: "#26211A", accentColorHex: "#8F4F2E",
            fontFamily: "Kaiti SC", fontSize: 20, lineHeight: 1.95
        )

        model.applyTheme(preset)

        #expect(model.readingSettings.theme == .sepia)
        #expect(model.readingSettings.fontSize == 20)
        #expect(model.readingSettings.lineHeight == 1.95)
    }

    @Test func independentFontSizeChangeDoesNotAffectPreset() {
        let repository = InMemoryBookRepository()
        let model = makeModel(bookRepository: repository)
        let preset = ThemePreset(
            name: "测试", baseTheme: .light,
            paperColorHex: "#FBF8F1", inkColorHex: "#26211A", accentColorHex: "#8F4F2E",
            fontSize: 18, lineHeight: 1.8
        )

        repository.saveTheme(preset)
        model.applyTheme(preset)
        model.setFontSize(22)

        let saved = repository.loadAllThemes().first { $0.name == "测试" }
        #expect(saved?.fontSize == 18)
        #expect(model.readingSettings.fontSize == 22)
    }

    @Test func savesCurrentAsNewTheme() {
        let repository = InMemoryBookRepository()
        let model = makeModel(bookRepository: repository)

        model.setFontSize(19)
        model.saveCurrentAsTheme(name: "我的搭配")

        #expect(model.themes.contains { $0.name == "我的搭配" })
        #expect(repository.loadAllThemes().contains { $0.name == "我的搭配" })
    }

    @Test func cannotDeleteBuiltInTheme() {
        let repository = InMemoryBookRepository()
        let model = makeModel(bookRepository: repository)
        let builtInId = ThemePreset.builtIn.first!.id

        model.deleteTheme(id: builtInId)

        #expect(model.themes.contains { $0.id == builtInId })
    }

    @Test func selectsPreviousAndNextChapters() async throws {
        let model = makeModel()
        let url = try temporaryFile(contents: """
        第一章 开始
        A
        第二章 继续
        B
        """)

        await model.loadTextFile(from: url)
        #expect(model.screen == .reader)
        #expect(model.currentChapter?.title == "第一章 开始")

        model.selectNextChapter()
        #expect(model.currentChapter?.title == "第二章 继续")

        model.selectPreviousChapter()
        #expect(model.currentChapter?.title == "第一章 开始")
    }

    @Test func persistsSettings() {
        let defaults = isolatedDefaults()
        var model = makeModel(defaults: defaults)

        model.setFontSize(20)
        model.setLineHeight(1.95)
        model.setTheme(.dark)
        model.setEmergencyBossCornerEnabled(false)
        model.setBookshelfStyle(.drawer)

        model = makeModel(defaults: defaults)
        #expect(model.readingSettings.fontSize == 20)
        #expect(model.readingSettings.lineHeight == 1.95)
        #expect(model.readingSettings.theme == .dark)
        #expect(model.readingSettings.isEmergencyBossCornerEnabled == false)
        #expect(model.readingSettings.bookshelfStyle == .drawer)
    }

    @Test func startsOnBookshelfAndRestoresChapterWhenBookIsOpened() async throws {
        let defaults = isolatedDefaults()
        let repository = InMemoryBookRepository()
        let url = try temporaryFile(contents: """
        第一章 开始
        A
        第二章 继续
        B
        """)
        var model = makeModel(defaults: defaults, bookRepository: repository)

        await model.loadTextFile(from: url)
        model.selectNextChapter()

        model = makeModel(defaults: defaults, bookRepository: repository)
        #expect(model.screen == .bookshelf)
        #expect(model.hasDocument == false)
        #expect(model.books.first?.title == "novel.txt")

        await model.openRecentFile(url)
        #expect(model.screen == .reader)
        #expect(model.currentChapter?.title == "第二章 继续")
        #expect(model.books.first?.title == "novel.txt")
    }

    @Test func loadsDroppedTextFileAndRejectsNonTextDrop() async throws {
        let model = makeModel()
        let txtURL = try temporaryFile(contents: "第一章\n正文", name: "novel.txt")
        let markdownURL = try temporaryFile(contents: "# 标题", name: "note.md")

        await model.loadTextFile(from: txtURL)
        #expect(model.screen == .reader)
        #expect(model.bookTitle == "novel.txt")

        #expect(model.loadDroppedFile(from: markdownURL) == false)
        #expect(model.errorMessage == "请拖入 TXT 文件。")
        #expect(model.bookTitle == "novel.txt")
    }

    @Test func canReturnToBookshelfWithoutClearingCurrentBook() async throws {
        let model = makeModel()
        let url = try temporaryFile(contents: "第一章\n正文")

        await model.loadTextFile(from: url)
        model.showBookshelf()

        #expect(model.screen == .bookshelf)
        #expect(model.bookTitle == url.lastPathComponent)
    }

    @Test func bossKeyActionHidesWindowWithoutClearingState() async throws {
        let registrar = FakeBossKeyRegistrar()
        let hider = FakeWindowHider()
        let model = makeModel(registrar: registrar, hider: hider)
        let url = try temporaryFile(contents: "第一章\n正文")

        await model.loadTextFile(from: url)
        registrar.trigger()

        #expect(hider.hideCallCount == 1)
        #expect(model.bookTitle == url.lastPathComponent)
        #expect(model.currentChapter?.title == "第一章")
    }

    @Test func reportsBossKeyRegistrationConflict() {
        let registrar = FakeBossKeyRegistrar()
        let rejectedShortcut = BossKeyShortcut(
            keyCode: UInt32(kVK_ANSI_J),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        registrar.rejectedShortcut = rejectedShortcut
        let model = makeModel(registrar: registrar)

        model.updateBossKeyShortcut(rejectedShortcut)

        #expect(model.bossKeyMessage == "快捷键不可用。")
        #expect(registrar.registeredShortcut == .default)
    }

    @Test func doesNotPersistConflictingBossKeyShortcut() {
        let defaults = isolatedDefaults()
        let registrar = FakeBossKeyRegistrar()
        registrar.errorToThrow = BossKeyRegistrationError.registrationFailed(OSStatus(eventHotKeyExistsErr))
        var model = makeModel(defaults: defaults, registrar: registrar)

        model.updateBossKeyShortcut(BossKeyShortcut(
            keyCode: UInt32(kVK_ANSI_J),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        ))

        #expect(model.bossKeyShortcut == .default)

        model = makeModel(defaults: defaults)
        #expect(model.bossKeyShortcut == .default)
    }

    @Test func rejectsSingleKeyGlobalBossShortcut() {
        let registrar = FakeBossKeyRegistrar()
        let model = makeModel(registrar: registrar)

        model.updateBossKeyShortcut(BossKeyShortcut(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: 0
        ))

        #expect(model.bossKeyShortcut == .default)
        #expect(registrar.registeredShortcut == .default)
        #expect(model.bossKeyMessage == "需使用组合键。")
    }

    @Test func shutdownUnregistersBossKeyShortcut() {
        let registrar = FakeBossKeyRegistrar()
        let model = makeModel(registrar: registrar)

        #expect(registrar.registeredShortcut == .default)

        model.shutdown()

        #expect(registrar.registeredShortcut == nil)
        #expect(registrar.unregisterCallCount == 1)
    }

    @Test func clearsDailyReadingSecondsOnNewDay() {
        let repository = InMemoryBookRepository()
        repository.saveDailyReadingSeconds(120)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        repository.saveReadingDate(yesterday)

        _ = makeModel(bookRepository: repository)

        #expect(repository.loadDailyReadingSeconds() == 0)
        #expect(repository.loadReadingDate() != nil)
    }

    @Test func pausesReadingTimerOnBossKey() async throws {
        let registrar = FakeBossKeyRegistrar()
        let hider = FakeWindowHider()
        let model = makeModel(registrar: registrar, hider: hider)
        let url = try temporaryFile(contents: "第一章\n正文")

        await model.loadTextFile(from: url)
        #expect(model.readingTimer.isCounting == true)

        model.performBossKeyAction()

        #expect(model.readingTimer.isCounting == false)
        #expect(hider.hideCallCount == 1)
    }

    private func makeModel(
        defaults: UserDefaults? = nil,
        registrar: FakeBossKeyRegistrar = FakeBossKeyRegistrar(),
        hider: FakeWindowHider = FakeWindowHider(),
        bookRepository: BookRepository = InMemoryBookRepository()
    ) -> ReaderModel {
        ReaderModel(
            defaults: defaults ?? isolatedDefaults(),
            loader: TextFileLoader(),
            bossKeyRegistrar: registrar,
            windowHider: hider,
            bookRepository: bookRepository
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "NovelReaderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func temporaryFile(contents: String, name: String = "novel.txt") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

@MainActor
private final class FakeBossKeyRegistrar: BossKeyRegistering {
    var registeredShortcut: BossKeyShortcut?
    var action: (() -> Void)?
    var errorToThrow: Error?
    var rejectedShortcut: BossKeyShortcut?
    private(set) var unregisterCallCount = 0

    func register(shortcut: BossKeyShortcut, action: @escaping () -> Void) throws {
        if shortcut == rejectedShortcut {
            throw BossKeyRegistrationError.registrationFailed(OSStatus(eventHotKeyExistsErr))
        }
        if let errorToThrow {
            throw errorToThrow
        }
        registeredShortcut = shortcut
        self.action = action
    }

    func unregister() {
        unregisterCallCount += 1
        registeredShortcut = nil
        action = nil
    }

    func trigger() {
        action?()
    }
}

@MainActor
private final class FakeWindowHider: WindowHiding {
    private(set) var hideCallCount = 0

    func hideReadingWindow() {
        hideCallCount += 1
    }
}
