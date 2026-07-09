import Combine
import Foundation
import SwiftUI

enum ReaderPanel: Equatable {
    case toc
    case settings
    case themes
    case search
    case onlineSearch
    case sources
}

enum ReaderScreen: Equatable {
    case bookshelf
    case reader
}

struct ChapterDirectoryItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

@MainActor
final class ReaderModel: ObservableObject {
    @Published private(set) var screen: ReaderScreen = .bookshelf
    @Published private(set) var document: NovelDocument?
    @Published private(set) var selectedChapterIndex = 0
    @Published var errorMessage: String?
    @Published var readingSettings: ReadingSettings {
        didSet {
            persistence.saveSettings(readingSettings)
        }
    }
    @Published var activePanel: ReaderPanel?
    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [SearchResultItem] = []
    @Published var searchJumpScrollOffset: CGFloat? = nil
    @Published var onlineSearchQuery: String = ""
    @Published private(set) var books: [Book]
    @Published private(set) var themes: [ThemePreset]

    @Published private(set) var bookSources: [BookSource] = []
    @Published var onlineSearchResults: [OnlineSearchResult] = []
    @Published private(set) var isLoadingOnline = false
    @Published private(set) var onlineBook: Book?
    @Published private(set) var onlineChapters: [OnlineChapter] = []
    @Published private(set) var downloadProgress: DownloadProgress?
    @Published private(set) var onlineChapterContents: [Int: String] = [:]

    let bossKey: BossKeyController
    let readingTimer: ReadingTimer

    private let persistence: ReaderPersistenceStore
    private let loader: TextFileLoading
    private let filePicker: FilePicking
    private let bookRepository: BookRepository
    private let bookSourceEngine: BookSourceEngine
    private let downloadBookSourceEngine: BookSourceEngine
    private let onlineCacheDirectoryOverride: URL?
    private var chapterContentProvider: ChapterContentProvider
    private var cancellables = Set<AnyCancellable>()
    private var chapterDetector = ChapterDetector()
    private var chapterCountCache: [UUID: Int] = [:]
    private var loadingOnlineChapterIndexes: Set<Int> = []
    private var downloadTask: Task<Void, Never>?
    private var downloadTaskID: UUID?

    init(
        defaults: UserDefaults = .standard,
        loader: TextFileLoading = TextFileLoader(),
        bossKeyRegistrar: BossKeyRegistering = CarbonBossKeyRegistrar.shared,
        windowHider: WindowHiding = AppKitWindowHider(),
        filePicker: FilePicking = NSOpenPanelFilePicker(),
        bookRepository: BookRepository? = nil,
        bookSourceEngine: BookSourceEngine? = nil,
        onlineCacheDirectory: URL? = nil
    ) {
        persistence = ReaderPersistenceStore(defaults: defaults)
        self.loader = loader
        self.filePicker = filePicker
        self.bookRepository = bookRepository ?? (try? SwiftDataBookRepository()) ?? InMemoryBookRepository()
        let resolvedBookSourceEngine = bookSourceEngine ?? LegadoBookSourceEngine()
        self.bookSourceEngine = resolvedBookSourceEngine
        downloadBookSourceEngine = bookSourceEngine == nil ? LegadoBookSourceEngine() : resolvedBookSourceEngine
        onlineCacheDirectoryOverride = onlineCacheDirectory
        chapterContentProvider = LocalChapterContentProvider(documentProvider: { nil })
        readingSettings = persistence.loadSettings()
        bossKey = BossKeyController(
            registrar: bossKeyRegistrar,
            persistence: persistence,
            windowHider: windowHider
        )
        readingTimer = ReadingTimer(repository: self.bookRepository)
        books = self.bookRepository.loadAllBooks()
        themes = self.bookRepository.loadAllThemes()
        bookSources = self.bookRepository.loadAllSources()
        chapterContentProvider = LocalChapterContentProvider(documentProvider: { [weak self] in self?.document })
        resetDailyReadingSecondsIfNewDay()
        migrateLegacyRecentFilesIfNeeded(defaults: defaults)
        bossKey.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        readingTimer.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var hasDocument: Bool {
        document != nil || onlineBook != nil
    }

    var isReadingOnline: Bool {
        onlineBook != nil
    }

    var isBookshelfVisible: Bool {
        screen == .bookshelf
    }

    var bookTitle: String {
        document?.displayTitle ?? onlineBook?.title ?? "未打开文件"
    }

    var chapterTitle: String {
        currentChapter?.title ?? "打开 TXT 开始阅读"
    }

    var documentText: String {
        currentChapter?.body ?? ""
    }

    var currentFileURL: URL? {
        document?.url
    }

    var currentChapter: NovelChapter? {
        if let document {
            guard document.chapters.indices.contains(selectedChapterIndex) else {
                return nil
            }
            return document.chapters[selectedChapterIndex]
        }

        guard onlineChapters.indices.contains(selectedChapterIndex) else {
            return nil
        }

        let chapter = onlineChapters[selectedChapterIndex]
        return NovelChapter(
            id: selectedChapterIndex,
            title: chapter.title,
            body: onlineChapterContents[selectedChapterIndex] ?? "",
            lineNumber: selectedChapterIndex + 1
        )
    }

    var chapters: [NovelChapter] {
        if let document {
            return document.chapters
        }
        return onlineChapters.enumerated().map { index, chapter in
            NovelChapter(
                id: index,
                title: chapter.title,
                body: onlineChapterContents[index] ?? "",
                lineNumber: index + 1
            )
        }
    }

    var chapterCount: Int {
        document?.chapters.count ?? onlineChapters.count
    }

    var chapterDirectoryItems: [ChapterDirectoryItem] {
        if let document {
            return document.chapters.map { chapter in
                ChapterDirectoryItem(id: chapter.id, title: chapter.title)
            }
        }

        return onlineChapters.enumerated().map { index, chapter in
            ChapterDirectoryItem(id: index, title: chapter.title)
        }
    }

    var chapterProgressText: String {
        guard hasDocument else {
            return "等待 TXT"
        }

        return "章节 \(selectedChapterIndex + 1) / \(max(chapterCount, 1))"
    }

    var selectedChapterDisplayText: String {
        guard hasDocument else {
            return "等待打开 TXT"
        }

        return "\(selectedChapterIndex + 1) / \(max(chapterCount, 1))"
    }

    var bossKeyShortcut: BossKeyShortcut { bossKey.shortcut }
    var bossKeyMessage: String? { bossKey.message }
    var isBossKeyRecording: Bool { bossKey.isRecording }

    func openTextFile() {
        Task {
            guard let picked = filePicker.pickTextFile(allowingEncodingSelection: true) else {
                return
            }

            await loadTextFile(from: picked.url, encoding: picked.encoding)
        }
    }

    func loadTextFile(from url: URL, encoding: String.Encoding? = nil) async {
        clearOnlineState()
        chapterContentProvider = LocalChapterContentProvider(documentProvider: { [weak self] in self?.document })
        refreshChapterPatternError()
        do {
            let nextDocument = try await loader.load(
                from: url,
                encoding: encoding,
                customChapterPattern: readingSettings.customChapterPattern
            )
            document = nextDocument
            selectedChapterIndex = min(
                persistence.loadChapterIndex(for: url),
                max(nextDocument.chapters.count - 1, 0)
            )
            errorMessage = nil
            persistence.saveLastFileURL(url)
            registerLocalBook(url: url, fileName: nextDocument.fileName)
            activePanel = nil
            exitBossKeyRecording()
            screen = .reader
            if let bookId = currentBookId {
                readingTimer.start(for: bookId)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法打开这个 TXT 文件。"
        }
    }

    private func registerLocalBook(url: URL, fileName: String) {
        let existing = books.first { book in
            if case .local(let bookURL) = book.origin, bookURL == url {
                return true
            }
            return false
        }

        if let existing {
            bookRepository.saveBook(existing)
        } else {
            let book = Book(
                title: fileName,
                origin: .local(url),
                lastReadPosition: ReadPosition(
                    chapterIndex: persistence.loadChapterIndex(for: url)
                )
            )
            bookRepository.saveBook(book)
            books = bookRepository.loadAllBooks()
        }
    }

    private func migrateLegacyRecentFilesIfNeeded(defaults: UserDefaults) {
        let key = "NovelReader.recentFiles"
        guard let paths = defaults.stringArray(forKey: key), paths.isEmpty == false else {
            return
        }

        for path in paths {
            let url = URL(fileURLWithPath: path)
            let alreadyExists = books.contains { book in
                if case .local(let bookURL) = book.origin, bookURL == url {
                    return true
                }
                return false
            }

            guard alreadyExists == false else { continue }

            let book = Book(
                title: url.lastPathComponent,
                origin: .local(url),
                lastReadPosition: ReadPosition(
                    chapterIndex: persistence.loadChapterIndex(for: url)
                )
            )
            bookRepository.saveBook(book)
        }

        books = bookRepository.loadAllBooks()
        defaults.removeObject(forKey: key)
    }

    @discardableResult
    func loadDroppedFile(from url: URL) -> Bool {
        guard url.pathExtension.localizedCaseInsensitiveCompare("txt") == .orderedSame else {
            errorMessage = "请拖入 TXT 文件。"
            return false
        }

        Task { await loadTextFile(from: url) }
        return true
    }

    func openRecentFile(_ url: URL) async {
        await loadTextFile(from: url)
    }

    func openBook(_ book: Book) async {
        switch book.origin {
        case .local(let url):
            await loadTextFile(from: url)
        case .online:
            await openOnlineBook(book: book)
        }
    }

    func deleteBook(id: UUID) {
        if let book = books.first(where: { $0.id == id }) {
            if case .local(let fileURL) = book.origin {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        bookRepository.deleteBook(id: id)
        chapterCountCache.removeValue(forKey: id)
        books = bookRepository.loadAllBooks()
    }

    func removeFromShelf(id: UUID) {
        bookRepository.deleteBook(id: id)
        chapterCountCache.removeValue(forKey: id)
        books = bookRepository.loadAllBooks()
    }

    func showBookshelf() {
        activePanel = nil
        exitBossKeyRecording()
        clearOnlineState()
        screen = .bookshelf
    }

    func selectChapter(id: NovelChapter.ID) {
        let index: Int
        if let document {
            guard let documentIndex = document.chapters.firstIndex(where: { $0.id == id }) else {
                return
            }
            index = documentIndex
        } else {
            guard onlineChapters.indices.contains(id) else {
                return
            }
            index = id
        }

        selectedChapterIndex = index
        saveCurrentChapterIndex()
        ensureOnlineChapterLoaded(at: index)
    }

    func selectPreviousChapter() {
        guard selectedChapterIndex > 0 else {
            return
        }

        selectedChapterIndex -= 1
        saveCurrentChapterIndex()
        ensureOnlineChapterLoaded(at: selectedChapterIndex)
    }

    func selectNextChapter() {
        guard selectedChapterIndex + 1 < chapterCount else {
            return
        }

        selectedChapterIndex += 1
        saveCurrentChapterIndex()
        ensureOnlineChapterLoaded(at: selectedChapterIndex)
    }

    func performSearch() {
        let chapterTuples = chapters.enumerated().map { index, chapter in
            (index: index, title: chapter.title, body: chapter.body)
        }
        searchResults = TextSearcher().search(query: searchQuery, in: chapterTuples)
    }

    func jumpToSearchResult(_ result: SearchResultItem) {
        guard chapters.indices.contains(result.chapterIndex) else {
            return
        }

        selectedChapterIndex = result.chapterIndex
        saveCurrentChapterIndex()
        let estimatedOffset = CGFloat(result.lineNumber) * readingSettings.fontSize * CGFloat(readingSettings.lineHeight)
        searchJumpScrollOffset = estimatedOffset
        closePanel()
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }

    func setFontSize(_ fontSize: Double) {
        readingSettings.fontSize = fontSize
    }

    func setLineHeight(_ lineHeight: Double) {
        readingSettings.lineHeight = lineHeight
    }

    func setTheme(_ theme: ReadingTheme) {
        readingSettings.theme = theme
    }

    func setReadingMode(_ mode: ReadingMode) {
        readingSettings.readingMode = mode
    }

    func applyTheme(_ preset: ThemePreset) {
        readingSettings = readingSettings.apply(preset: preset)
    }

    func saveCurrentAsTheme(name: String) {
        let preset = ThemePreset(
            name: name,
            baseTheme: readingSettings.theme,
            paperColorHex: ThemePreset.builtIn.first { $0.baseTheme == readingSettings.theme }?.paperColorHex ?? "#FBF8F1",
            inkColorHex: ThemePreset.builtIn.first { $0.baseTheme == readingSettings.theme }?.inkColorHex ?? "#26211A",
            accentColorHex: ThemePreset.builtIn.first { $0.baseTheme == readingSettings.theme }?.accentColorHex ?? "#8F4F2E",
            fontFamily: "Songti SC",
            fontSize: readingSettings.fontSize,
            lineHeight: readingSettings.lineHeight,
            isBuiltIn: false
        )
        bookRepository.saveTheme(preset)
        themes = bookRepository.loadAllThemes()
    }

    func deleteTheme(id: UUID) {
        bookRepository.deleteTheme(id: id)
        themes = bookRepository.loadAllThemes()
    }

    func setEmergencyBossCornerEnabled(_ isEnabled: Bool) {
        readingSettings.isEmergencyBossCornerEnabled = isEnabled
    }

    func setBookshelfStyle(_ style: BookshelfStyle) {
        readingSettings.bookshelfStyle = style
    }

    func setCustomChapterPattern(_ pattern: String?) {
        readingSettings.customChapterPattern = pattern
        chapterCountCache.removeAll()
        refreshChapterPatternError()
    }

    func togglePanel(_ panel: ReaderPanel) {
        if activePanel == panel {
            closePanel()
        } else {
            activePanel = panel
            exitBossKeyRecording()
        }
    }

    func closePanel() {
        activePanel = nil
        exitBossKeyRecording()
    }

    func startBossKeyRecording() {
        bossKey.startRecording()
    }

    func updateBossKeyShortcut(_ shortcut: BossKeyShortcut) {
        bossKey.updateShortcut(shortcut)
    }

    func performBossKeyAction() {
        readingTimer.pause()
        chapterContentProvider.pause()
        bookSourceEngine.pause()
        bossKey.activate()
    }

    func resumeOnlineLoading() {
        bookSourceEngine.resume()
        chapterContentProvider.resume()
    }

    func shutdown() {
        cancelDownload()
        bossKey.shutdown()
    }

    private func exitBossKeyRecording() {
        bossKey.exitRecording()
    }

    private func saveCurrentChapterIndex() {
        if let url = document?.url {
            persistence.saveChapterIndex(selectedChapterIndex, for: url)
        }
        if let bookId = currentBookId, onlineBook != nil {
            var position = bookRepository.loadReadPosition(for: bookId) ?? ReadPosition()
            position.chapterIndex = selectedChapterIndex
            bookRepository.saveReadPosition(position, for: bookId)
        }
    }

    func saveScrollOffset(_ offset: CGFloat) {
        guard let bookId = currentBookId else {
            return
        }

        let position = ReadPosition(
            chapterIndex: selectedChapterIndex,
            scrollOffset: Double(offset)
        )
        bookRepository.saveReadPosition(position, for: bookId)
    }

    func loadScrollOffset() -> CGFloat {
        guard let bookId = currentBookId,
              let position = bookRepository.loadReadPosition(for: bookId) else {
            return 0
        }

        return CGFloat(position.scrollOffset)
    }

    func addReadingSeconds(_ seconds: Double) {
        guard let bookId = currentBookId else {
            return
        }

        bookRepository.addReadingSeconds(seconds, for: bookId)
    }

    var todayReadingMinutes: Int {
        Int(bookRepository.loadDailyReadingSeconds() / 60)
    }

    var totalReadingMinutes: Int {
        let total = books.reduce(0.0) { $0 + $1.totalReadingSeconds }
        return Int(total / 60)
    }

    var chapterPatternError: String? {
        chapterDetector.lastCustomPatternError
    }

    private func refreshChapterPatternError() {
        chapterDetector.refreshCustomPatternError(readingSettings.customChapterPattern)
    }

    func readingProgress(for book: Book) -> Double {
        switch book.origin {
        case .local(let url):
            if let cached = chapterCountCache[book.id] {
                guard cached > 1 else { return 0 }
                return book.readingProgress(totalChapters: cached)
            }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
            let chapters = ChapterDetector().detectChapters(
                in: text,
                customPattern: readingSettings.customChapterPattern
            )
            chapterCountCache[book.id] = chapters.count
            guard chapters.count > 1 else { return 0 }
            return book.readingProgress(totalChapters: chapters.count)
        case .online:
            return 0
        }
    }

    private func resetDailyReadingSecondsIfNewDay() {
        let calendar = Calendar.current
        if let savedDate = bookRepository.loadReadingDate() {
            guard calendar.isDateInToday(savedDate) else {
                bookRepository.saveDailyReadingSeconds(0)
                bookRepository.saveReadingDate(Date())
                return
            }
        } else {
            bookRepository.saveReadingDate(Date())
        }
    }

    var currentBookId: UUID? {
        if let url = document?.url {
            return books.first { book in
                if case .local(let bookURL) = book.origin, bookURL == url {
                    return true
                }
                return false
            }?.id
        }
        return onlineBook?.id
    }

    func savedChapterIndex(for url: URL) -> Int {
        persistence.loadChapterIndex(for: url)
    }

    func savedOnlineChapterIndex(for book: Book) -> Int {
        bookRepository.loadReadPosition(for: book.id)?.chapterIndex ?? 0
    }

    func importBookSources(from url: URL) {
        Task {
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "无法读取书源文件。"
                return
            }
            do {
                let sources = try BookSource.decode(from: data)
                for source in sources {
                    bookRepository.saveSource(source)
                }
                bookSources = bookRepository.loadAllSources()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "书源格式不正确。"
            }
        }
    }

    func importBookSourcesViaPicker() {
        let sources = filePicker.pickBookSourceFile()
        for source in sources {
            bookRepository.saveSource(source)
        }
        bookSources = bookRepository.loadAllSources()
    }

    func importBookSourcesFromURL(_ url: URL) {
        Task { @MainActor in
            isLoadingOnline = true
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let sources = try BookSource.decode(from: data)
                for source in sources {
                    bookRepository.saveSource(source)
                }
                bookSources = bookRepository.loadAllSources()
            } catch {
                errorMessage = "无法下载书源：\(error.localizedDescription)"
            }
            isLoadingOnline = false
        }
    }

    func toggleSourceEnabled(_ source: BookSource) {
        var updated = source
        updated.isEnabled.toggle()
        bookRepository.saveSource(updated)
        bookSources = bookRepository.loadAllSources()
    }

    func deleteSource(id: String) {
        bookRepository.deleteSource(id: id)
        bookSources = bookRepository.loadAllSources()
    }

    func setSourcesEnabled(_ enabled: Bool, ids: [String]) {
        for id in ids {
            if var source = bookSources.first(where: { $0.id == id }) {
                source.isEnabled = enabled
                bookRepository.saveSource(source)
            }
        }
        bookSources = bookRepository.loadAllSources()
    }

    func setAllSourcesEnabled(_ enabled: Bool) {
        for var source in bookSources {
            if source.isEnabled != enabled {
                source.isEnabled = enabled
                bookRepository.saveSource(source)
            }
        }
        bookSources = bookRepository.loadAllSources()
    }

    func deleteSources(ids: [String]) {
        for id in ids {
            bookRepository.deleteSource(id: id)
        }
        bookSources = bookRepository.loadAllSources()
    }

    func deleteAllSources() {
        for source in bookSources {
            bookRepository.deleteSource(id: source.id)
        }
        bookSources = bookRepository.loadAllSources()
    }

    func searchOnline(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            onlineSearchResults = []
            return
        }
        onlineSearchQuery = trimmed
        Task {
            isLoadingOnline = true
            let enabled = bookSources.filter { $0.isEnabled }
            let results = await bookSourceEngine.search(query: trimmed, sources: enabled)
            onlineSearchResults = results
            isLoadingOnline = false
        }
    }

    func openOnlineSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        onlineSearchQuery = trimmed
        activePanel = .onlineSearch
        if trimmed.isEmpty == false {
            searchOnline(query: trimmed)
        }
    }

    func addOnlineBookToShelf(_ result: OnlineSearchResult) {
        let existing = books.first { book in
            if case .online(_, let bookUrl) = book.origin, bookUrl == result.bookUrl {
                return true
            }
            return false
        }

        if let existing {
            bookRepository.saveBook(existing)
        } else {
            let book = Book(
                title: result.title,
                author: result.author,
                origin: .online(sourceId: result.sourceId, bookUrl: result.bookUrl)
            )
            bookRepository.saveBook(book)
            books = bookRepository.loadAllBooks()
        }
    }

    func downloadOnlineBook(_ result: OnlineSearchResult) {
        guard downloadTask == nil else {
            errorMessage = "已有下载任务正在进行。"
            return
        }

        guard let source = bookSources.first(where: { $0.id == result.sourceId }) else {
            errorMessage = "找不到对应的书源。"
            return
        }

        let taskID = UUID()
        downloadTaskID = taskID
        downloadProgress = DownloadProgress(title: result.title, current: 0, total: 0)

        downloadTask = Task {
            do {
                try Task.checkCancellation()

                let chapters = try await downloadBookSourceEngine.loadChapterList(bookUrl: result.bookUrl, source: source)
                try Task.checkCancellation()
                guard chapters.isEmpty == false else {
                    throw BookSourceError.chapterNotFound
                }

                downloadProgress = DownloadProgress(title: result.title, current: 0, total: chapters.count)

                var pieces: [String] = []
                for (index, chapter) in chapters.enumerated() {
                    try Task.checkCancellation()

                    let content = try await downloadBookSourceEngine.loadChapterContent(chapterUrl: chapter.url, source: source)
                    try Task.checkCancellation()

                    pieces.append(chapter.title + "\n" + content)
                    downloadProgress = DownloadProgress(title: result.title, current: index + 1, total: chapters.count)
                }

                let text = pieces.joined(separator: "\n\n")
                let url = saveDownloadedText(text, title: result.title)

                let book = Book(
                    title: result.title,
                    author: result.author,
                    origin: .local(url)
                )
                bookRepository.saveBook(book)
                books = bookRepository.loadAllBooks()
            } catch {
                if Task.isCancelled == false {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "下载失败。"
                }
            }

            clearDownload(taskID: taskID)
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadProgress = nil
    }

    private func clearDownload(taskID: UUID) {
        guard downloadTaskID == taskID else {
            return
        }

        downloadTask = nil
        downloadTaskID = nil
        downloadProgress = nil
    }

    private func saveDownloadedText(_ text: String, title: String) -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MujianDownloads", isDirectory: true) ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeName = title.replacingOccurrences(of: "/", with: "_")
        let url = directory.appendingPathComponent("\(safeName).txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func openOnlineBook(book: Book) async {
        guard case .online(let sourceId, let bookUrl) = book.origin else {
            errorMessage = "找不到对应的书源。"
            return
        }
        let source = bookSources.first(where: { $0.id == sourceId })

        isLoadingOnline = true
        document = nil
        onlineBook = book
        onlineChapters = []
        onlineChapterContents = [:]
        loadingOnlineChapterIndexes = []
        selectedChapterIndex = max(book.lastReadPosition.chapterIndex, 0)
        activePanel = nil
        exitBossKeyRecording()
        screen = .reader

        let provider = OnlineChapterContentProvider(
            engine: bookSourceEngine,
            sourcesProvider: { [weak self] in self?.bookSources ?? [] },
            bookLookup: { [weak self] id in self?.books.first { $0.id == id } },
            cacheDirectory: onlineCacheDirectory
        )
        chapterContentProvider = provider

        do {
            let chapters: [OnlineChapter]
            if let cachedChapters = provider.cachedChapterList(for: book.id) {
                chapters = cachedChapters
                if let source {
                    refreshCachedOnlineChapterList(
                        for: book,
                        source: source,
                        provider: provider,
                        cachedCount: cachedChapters.count
                    )
                }
            } else if let source {
                chapters = try await bookSourceEngine.loadChapterList(bookUrl: bookUrl, source: source)
                provider.preloadChapterList(chapters, for: book.id)
            } else {
                throw ChapterContentError.sourceUnavailable
            }

            onlineChapters = chapters
            if selectedChapterIndex >= chapters.count {
                selectedChapterIndex = max(chapters.count - 1, 0)
            }
            await loadOnlineChapterContent(at: selectedChapterIndex)
            if let bookId = currentBookId {
                readingTimer.start(for: bookId)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "加载目录失败。"
        }
        isLoadingOnline = false
    }

    private func refreshCachedOnlineChapterList(
        for book: Book,
        source: BookSource,
        provider: OnlineChapterContentProvider,
        cachedCount: Int
    ) {
        guard case .online(_, let bookUrl) = book.origin else {
            return
        }

        Task {
            do {
                let refreshedChapters = try await bookSourceEngine.loadChapterList(bookUrl: bookUrl, source: source)
                guard refreshedChapters.count >= cachedCount,
                      chapterListSignature(refreshedChapters) != chapterListSignature(onlineChapters) else {
                    return
                }

                provider.preloadChapterList(refreshedChapters, for: book.id)

                guard onlineBook?.id == book.id else {
                    return
                }

                onlineChapters = refreshedChapters
                if selectedChapterIndex >= refreshedChapters.count {
                    selectedChapterIndex = max(refreshedChapters.count - 1, 0)
                }
            } catch {
                return
            }
        }
    }

    private func chapterListSignature(_ chapters: [OnlineChapter]) -> [String] {
        chapters.map { "\($0.title)\n\($0.url)" }
    }

    func loadOnlineChapterContent(
        at index: Int,
        showsLoadingIndicator: Bool = true,
        prefetchNext: Bool = true
    ) async {
        guard onlineBook != nil, onlineChapters.indices.contains(index) else { return }
        if onlineChapterContents[index] != nil { return }
        if loadingOnlineChapterIndexes.contains(index) { return }
        guard let bookId = currentBookId else { return }
        let wasCached = chapterContentProvider.isCached(bookId: bookId, chapterIndex: index)
        loadingOnlineChapterIndexes.insert(index)
        if showsLoadingIndicator {
            isLoadingOnline = true
        }
        defer {
            loadingOnlineChapterIndexes.remove(index)
            if showsLoadingIndicator {
                isLoadingOnline = false
            }
        }
        do {
            let content = try await chapterContentProvider.content(for: bookId, chapterIndex: index)
            onlineChapterContents[index] = content
            if prefetchNext, wasCached == false {
                preloadOnlineChapterContent(at: index + 1)
            }
        } catch {
            if showsLoadingIndicator {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "加载正文失败。"
            }
        }
    }

    private func ensureOnlineChapterLoaded(at index: Int) {
        guard onlineBook != nil else { return }
        Task { await loadOnlineChapterContent(at: index) }
    }

    private func preloadOnlineChapterContent(at index: Int) {
        guard onlineBook != nil,
              onlineChapters.indices.contains(index),
              onlineChapterContents[index] == nil,
              loadingOnlineChapterIndexes.contains(index) == false else {
            return
        }

        Task {
            await loadOnlineChapterContent(
                at: index,
                showsLoadingIndicator: false,
                prefetchNext: false
            )
        }
    }

    private func clearOnlineState() {
        onlineBook = nil
        onlineChapters = []
        onlineChapterContents = [:]
        loadingOnlineChapterIndexes = []
    }

    private var onlineCacheDirectory: URL {
        if let onlineCacheDirectoryOverride {
            return onlineCacheDirectoryOverride
        }

        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MujianOnlineCache", isDirectory: true) ?? FileManager.default.temporaryDirectory
    }
}
