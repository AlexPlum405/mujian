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

    @Test func openingOnlineBookPrefetchesNextChapter() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        let book = Book(title: "在线书", origin: .online(sourceId: source.id, bookUrl: "https://example.com/book"))
        repository.saveSource(source)
        repository.saveBook(book)

        let engine = StubBookSourceEngine()
        engine.chapters = [
            OnlineChapter(title: "第一章", url: "https://example.com/c1"),
            OnlineChapter(title: "第二章", url: "https://example.com/c2")
        ]
        engine.content = "在线正文"

        let model = makeModel(bookRepository: repository, bookSourceEngine: engine)

        await model.openBook(book)

        #expect(model.onlineChapterContents[0] == "在线正文")

        for _ in 0..<20 {
            if model.onlineChapterContents[1] != nil {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(model.onlineChapterContents[1] == "在线正文")
    }

    @Test func openingOnlineBookUsesCachedDirectoryAndChapterWithoutNetwork() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        let book = Book(title: "缓存书", origin: .online(sourceId: source.id, bookUrl: "https://example.com/book"))
        let cacheDirectory = try temporaryDirectory()
        repository.saveSource(source)
        repository.saveBook(book)

        let firstEngine = StubBookSourceEngine()
        firstEngine.chapters = [
            OnlineChapter(title: "第一章", url: "https://example.com/c1"),
            OnlineChapter(title: "第二章", url: "https://example.com/c2")
        ]
        firstEngine.content = "缓存正文"

        let firstModel = makeModel(
            bookRepository: repository,
            bookSourceEngine: firstEngine,
            onlineCacheDirectory: cacheDirectory
        )

        await firstModel.openBook(book)

        #expect(firstModel.chapterCount == 2)
        #expect(firstModel.documentText == "缓存正文")

        let offlineEngine = StubBookSourceEngine()
        offlineEngine.chapterListError = BookSourceError.network("不该请求目录")
        offlineEngine.contentError = BookSourceError.network("不该请求正文")

        let secondModel = makeModel(
            bookRepository: repository,
            bookSourceEngine: offlineEngine,
            onlineCacheDirectory: cacheDirectory
        )

        await secondModel.openBook(book)

        #expect(secondModel.chapterCount == 2)
        #expect(secondModel.chapterDirectoryItems.map(\.title) == ["第一章", "第二章"])
        #expect(secondModel.documentText == "缓存正文")
        #expect(secondModel.errorMessage == nil)
        #expect(offlineEngine.loadChapterListCallCount == 0)
        #expect(offlineEngine.loadChapterContentCallCount == 0)
    }

    @Test func openingOnlineBookRefreshesStaleCachedDirectoryInBackground() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        let book = Book(title: "旧目录书", origin: .online(sourceId: source.id, bookUrl: "https://example.com/book"))
        let cacheDirectory = try temporaryDirectory()
        repository.saveSource(source)
        repository.saveBook(book)

        let staleProvider = OnlineChapterContentProvider(
            engine: StubBookSourceEngine(),
            sourcesProvider: { [source] },
            bookLookup: { id in id == book.id ? book : nil },
            cacheDirectory: cacheDirectory
        )
        staleProvider.preloadChapterList([
            OnlineChapter(title: "第一章", url: "https://example.com/c1"),
            OnlineChapter(title: "第二章", url: "https://example.com/c2")
        ], for: book.id)

        let engine = DelayedChapterListEngine(
            chapters: [
                OnlineChapter(title: "第一章", url: "https://example.com/c1"),
                OnlineChapter(title: "第二章", url: "https://example.com/c2"),
                OnlineChapter(title: "第三章", url: "https://example.com/c3"),
                OnlineChapter(title: "第四章", url: "https://example.com/c4")
            ],
            content: "刷新正文",
            delayNanoseconds: 120_000_000
        )
        let model = makeModel(
            bookRepository: repository,
            bookSourceEngine: engine,
            onlineCacheDirectory: cacheDirectory
        )

        await model.openBook(book)

        #expect(model.chapterCount == 2)

        for _ in 0..<20 {
            if model.chapterCount == 4 {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(model.chapterCount == 4)
        #expect(model.chapterDirectoryItems.map(\.title) == ["第一章", "第二章", "第三章", "第四章"])
        #expect(engine.loadChapterListCallCount == 1)

        let offlineEngine = StubBookSourceEngine()
        offlineEngine.chapterListError = BookSourceError.network("刷新后不该重新请求目录")
        offlineEngine.content = "离线正文"
        let secondModel = makeModel(
            bookRepository: repository,
            bookSourceEngine: offlineEngine,
            onlineCacheDirectory: cacheDirectory
        )

        await secondModel.openBook(book)

        #expect(secondModel.chapterCount == 4)
        #expect(offlineEngine.loadChapterListCallCount == 0)
    }

    @Test func openingOnlineBookRefreshesCachedDirectoryWhenOrderChanges() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        let book = Book(title: "错序目录书", origin: .online(sourceId: source.id, bookUrl: "https://example.com/book"))
        let cacheDirectory = try temporaryDirectory()
        repository.saveSource(source)
        repository.saveBook(book)

        let staleProvider = OnlineChapterContentProvider(
            engine: StubBookSourceEngine(),
            sourcesProvider: { [source] },
            bookLookup: { id in id == book.id ? book : nil },
            cacheDirectory: cacheDirectory
        )
        staleProvider.preloadChapterList([
            OnlineChapter(title: "第1945章 立序理旧罪", url: "https://example.com/c1945"),
            OnlineChapter(title: "第一章 阳芝武毅", url: "https://example.com/c1")
        ], for: book.id)

        let engine = DelayedChapterListEngine(
            chapters: [
                OnlineChapter(title: "第一章 阳芝武毅", url: "https://example.com/c1"),
                OnlineChapter(title: "第1945章 立序理旧罪", url: "https://example.com/c1945")
            ],
            content: "刷新正文",
            delayNanoseconds: 120_000_000
        )
        let model = makeModel(
            bookRepository: repository,
            bookSourceEngine: engine,
            onlineCacheDirectory: cacheDirectory
        )

        await model.openBook(book)

        #expect(model.chapterDirectoryItems.first?.title == "第1945章 立序理旧罪")

        for _ in 0..<20 {
            if model.chapterDirectoryItems.first?.title == "第一章 阳芝武毅" {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(model.chapterCount == 2)
        #expect(model.chapterDirectoryItems.map(\.title) == ["第一章 阳芝武毅", "第1945章 立序理旧罪"])
    }

    @Test func openOnlineSearchSeedsQueryAndSearchesEnabledSources() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        repository.saveSource(source)

        let engine = StubBookSourceEngine()
        engine.searchResults = [
            OnlineSearchResult(
                title: "寂静杀戮",
                author: "熊狼狗",
                bookUrl: "https://example.com/book",
                sourceId: source.id,
                sourceName: source.name
            )
        ]

        let model = makeModel(bookRepository: repository, bookSourceEngine: engine)

        model.openOnlineSearch(query: "  寂静杀戮  ")

        for _ in 0..<20 {
            if model.onlineSearchResults.isEmpty == false {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(model.activePanel == .onlineSearch)
        #expect(model.onlineSearchQuery == "寂静杀戮")
        #expect(engine.lastSearchQuery == "寂静杀戮")
        #expect(model.onlineSearchResults.first?.title == "寂静杀戮")
    }

    @Test func downloadOnlineBookContinuesAfterPanelCloses() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        repository.saveSource(source)

        let engine = StubBookSourceEngine()
        engine.chapters = [
            OnlineChapter(title: "第一章", url: "https://example.com/c1"),
            OnlineChapter(title: "第二章", url: "https://example.com/c2")
        ]
        engine.content = "下载正文"

        let model = makeModel(bookRepository: repository, bookSourceEngine: engine)
        model.togglePanel(.onlineSearch)

        model.downloadOnlineBook(OnlineSearchResult(
            title: "下载书",
            author: "作者",
            bookUrl: "https://example.com/book",
            sourceId: source.id,
            sourceName: source.name
        ))
        model.closePanel()

        for _ in 0..<20 {
            if model.downloadProgress == nil, model.books.contains(where: { $0.title == "下载书" }) {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(model.activePanel == nil)
        #expect(model.downloadProgress == nil)
        #expect(model.books.contains { $0.title == "下载书" })
    }

    @Test func cancelDownloadStopsTaskWithoutSavingBook() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        repository.saveSource(source)

        let engine = SlowDownloadEngine()
        engine.chapters = [
            OnlineChapter(title: "第一章", url: "https://example.com/c1")
        ]

        let model = makeModel(bookRepository: repository, bookSourceEngine: engine)
        model.downloadOnlineBook(OnlineSearchResult(
            title: "慢下载",
            author: nil,
            bookUrl: "https://example.com/book",
            sourceId: source.id,
            sourceName: source.name
        ))

        for _ in 0..<20 {
            if model.downloadProgress?.total == 1 {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        model.cancelDownload()
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(model.downloadProgress == nil)
        #expect(model.errorMessage == nil)
        #expect(model.books.contains { $0.title == "慢下载" } == false)
        #expect(engine.loadChapterContentCallCount == 1)
    }

    @Test func onlineBookExposesLightweightDirectoryItemsForLargeToc() async throws {
        let repository = InMemoryBookRepository()
        let source = makeSource()
        let book = Book(title: "长篇在线书", origin: .online(sourceId: source.id, bookUrl: "https://example.com/book"))
        repository.saveSource(source)
        repository.saveBook(book)

        let engine = StubBookSourceEngine()
        engine.chapters = (0..<5_000).map { index in
            OnlineChapter(title: "第 \(index + 1) 章", url: "https://example.com/c\(index)")
        }
        engine.content = "在线正文"

        let model = makeModel(bookRepository: repository, bookSourceEngine: engine)

        await model.openBook(book)

        #expect(model.chapterCount == 5_000)
        #expect(model.chapterDirectoryItems.count == 5_000)
        #expect(model.chapterDirectoryItems[4_999].title == "第 5000 章")
        #expect(model.currentChapter?.body == "在线正文")

        model.selectChapter(id: 4_999)

        for _ in 0..<20 {
            if model.onlineChapterContents[4_999] != nil {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(model.selectedChapterIndex == 4_999)
        #expect(model.currentChapter?.title == "第 5000 章")
        #expect(model.currentChapter?.body == "在线正文")
    }

    private func makeModel(
        defaults: UserDefaults? = nil,
        registrar: FakeBossKeyRegistrar = FakeBossKeyRegistrar(),
        hider: FakeWindowHider = FakeWindowHider(),
        bookRepository: BookRepository = InMemoryBookRepository(),
        bookSourceEngine: BookSourceEngine = StubBookSourceEngine(),
        onlineCacheDirectory: URL? = nil
    ) -> ReaderModel {
        ReaderModel(
            defaults: defaults ?? isolatedDefaults(),
            loader: TextFileLoader(),
            bossKeyRegistrar: registrar,
            windowHider: hider,
            bookRepository: bookRepository,
            bookSourceEngine: bookSourceEngine,
            onlineCacheDirectory: onlineCacheDirectory
        )
    }

    private func makeSource(id: String = "s1", name: String = "源一", url: String = "https://example.com") -> BookSource {
        BookSource(
            id: id,
            name: name,
            url: url,
            searchUrl: "https://example.com/s?q={{searchKey}}",
            isEnabled: true,
            searchRule: ".item",
            titleRule: ".title@text",
            authorRule: ".author@text",
            chapterListRule: ".chapters>li",
            chapterTitleRule: "a@text",
            chapterUrlRule: "a@href",
            contentRule: "#content@text"
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

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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

private final class SlowDownloadEngine: BookSourceEngine, @unchecked Sendable {
    var chapters: [OnlineChapter] = []
    private(set) var loadChapterContentCallCount = 0

    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult] {
        []
    }

    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter] {
        chapters
    }

    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String {
        loadChapterContentCallCount += 1
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return "慢正文"
    }

    func pause() {}
    func resume() {}
}

private final class DelayedChapterListEngine: BookSourceEngine, @unchecked Sendable {
    let chapters: [OnlineChapter]
    let content: String
    let delayNanoseconds: UInt64
    private(set) var loadChapterListCallCount = 0

    init(chapters: [OnlineChapter], content: String, delayNanoseconds: UInt64) {
        self.chapters = chapters
        self.content = content
        self.delayNanoseconds = delayNanoseconds
    }

    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult] {
        []
    }

    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter] {
        loadChapterListCallCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return chapters
    }

    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String {
        content
    }

    func pause() {}
    func resume() {}
}
