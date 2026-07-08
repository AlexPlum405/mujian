import Foundation
import SwiftData

@Model
final class BookRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String?
    var originType: String
    var originPath: String?
    var originSourceId: String?
    var originBookUrl: String?
    var chapterIndex: Int
    var scrollOffset: Double
    var pageIndex: Int?
    var addedAt: Date
    var lastReadAt: Date?
    var totalReadingSeconds: Double

    init(
        id: UUID,
        title: String,
        author: String?,
        originType: String,
        originPath: String?,
        originSourceId: String?,
        originBookUrl: String?,
        chapterIndex: Int,
        scrollOffset: Double,
        pageIndex: Int?,
        addedAt: Date,
        lastReadAt: Date?,
        totalReadingSeconds: Double
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.originType = originType
        self.originPath = originPath
        self.originSourceId = originSourceId
        self.originBookUrl = originBookUrl
        self.chapterIndex = chapterIndex
        self.scrollOffset = scrollOffset
        self.pageIndex = pageIndex
        self.addedAt = addedAt
        self.lastReadAt = lastReadAt
        self.totalReadingSeconds = totalReadingSeconds
    }
}

@Model
final class ReadingStatsRecord {
    @Attribute(.unique) var key: String
    var dailySeconds: Double
    var readingDate: Date

    init(key: String, dailySeconds: Double, readingDate: Date) {
        self.key = key
        self.dailySeconds = dailySeconds
        self.readingDate = readingDate
    }
}

@Model
final class ThemeRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseThemeRaw: String
    var paperColorHex: String
    var inkColorHex: String
    var accentColorHex: String
    var fontFamily: String
    var fontSize: Double
    var lineHeight: Double
    var isBuiltIn: Bool

    init(
        id: UUID, name: String, baseThemeRaw: String,
        paperColorHex: String, inkColorHex: String, accentColorHex: String,
        fontFamily: String, fontSize: Double, lineHeight: Double, isBuiltIn: Bool
    ) {
        self.id = id
        self.name = name
        self.baseThemeRaw = baseThemeRaw
        self.paperColorHex = paperColorHex
        self.inkColorHex = inkColorHex
        self.accentColorHex = accentColorHex
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.isBuiltIn = isBuiltIn
    }
}

@Model
final class BookSourceRecord {
    @Attribute(.unique) var id: String
    var name: String
    var url: String
    var searchUrl: String
    var isEnabled: Bool
    var searchRule: String
    var titleRule: String
    var authorRule: String
    var bookUrlRule: String
    var introRule: String
    var chapterListRule: String
    var chapterTitleRule: String
    var chapterUrlRule: String
    var contentRule: String

    init(
        id: String, name: String, url: String, searchUrl: String, isEnabled: Bool,
        searchRule: String, titleRule: String, authorRule: String,
        bookUrlRule: String, introRule: String,
        chapterListRule: String, chapterTitleRule: String, chapterUrlRule: String, contentRule: String
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.searchUrl = searchUrl
        self.isEnabled = isEnabled
        self.searchRule = searchRule
        self.titleRule = titleRule
        self.authorRule = authorRule
        self.bookUrlRule = bookUrlRule
        self.introRule = introRule
        self.chapterListRule = chapterListRule
        self.chapterTitleRule = chapterTitleRule
        self.chapterUrlRule = chapterUrlRule
        self.contentRule = contentRule
    }
}

@MainActor
final class SwiftDataBookRepository: BookRepository {
    private let container: ModelContainer

    init(container: ModelContainer? = nil) throws {
        if let container {
            self.container = container
        } else {
            self.container = try ModelContainer(
                for: BookRecord.self, ReadingStatsRecord.self, ThemeRecord.self, BookSourceRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        }
    }

    private var context: ModelContext { container.mainContext }

    func loadAllBooks() -> [Book] {
        let descriptor = FetchDescriptor<BookRecord>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        guard let records = try? context.fetch(descriptor) else { return [] }
        return records.map { Self.toBook($0) }
    }

    func saveBook(_ book: Book) {
        let bookId = book.id
        let descriptor = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.id == bookId })
        if let existing = try? context.fetch(descriptor).first {
            Self.apply(book, to: existing)
        } else {
            let record = Self.toRecord(book)
            context.insert(record)
        }
        try? context.save()
    }

    func deleteBook(id: UUID) {
        let bookId = id
        let descriptor = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.id == bookId })
        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
    }

    func loadReadPosition(for bookId: UUID) -> ReadPosition? {
        let targetId = bookId
        let descriptor = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.id == targetId })
        guard let record = try? context.fetch(descriptor).first else { return nil }
        return ReadPosition(chapterIndex: record.chapterIndex, scrollOffset: record.scrollOffset, pageIndex: record.pageIndex)
    }

    func saveReadPosition(_ position: ReadPosition, for bookId: UUID) {
        let targetId = bookId
        let descriptor = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.id == targetId })
        guard let record = try? context.fetch(descriptor).first else { return }
        record.chapterIndex = position.chapterIndex
        record.scrollOffset = position.scrollOffset
        record.pageIndex = position.pageIndex
        try? context.save()
    }

    func loadReadingSeconds(for bookId: UUID) -> Double {
        let targetId = bookId
        let descriptor = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.id == targetId })
        let record = try? context.fetch(descriptor).first
        return record?.totalReadingSeconds ?? 0
    }

    func addReadingSeconds(_ seconds: Double, for bookId: UUID) {
        let targetId = bookId
        let descriptor = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.id == targetId })
        guard let record = try? context.fetch(descriptor).first else { return }
        record.totalReadingSeconds += seconds
        try? context.save()
    }

    func loadDailyReadingSeconds() -> Double {
        guard let record = fetchStatsRecord() else { return 0 }
        return record.dailySeconds
    }

    func saveDailyReadingSeconds(_ seconds: Double) {
        let record = fetchStatsRecord() ?? createStatsRecord()
        record.dailySeconds = seconds
        try? context.save()
    }

    func loadReadingDate() -> Date? {
        fetchStatsRecord()?.readingDate
    }

    func saveReadingDate(_ date: Date) {
        let record = fetchStatsRecord() ?? createStatsRecord()
        record.readingDate = date
        try? context.save()
    }

    private var cachedThemes: [ThemePreset]?

    func loadAllThemes() -> [ThemePreset] {
        if let cached = cachedThemes {
            return cached
        }
        let descriptor = FetchDescriptor<ThemeRecord>(sortBy: [SortDescriptor(\.name)])
        let records = (try? context.fetch(descriptor)) ?? []
        let themes = records.map { Self.toThemePreset($0) }
        let result = ThemePreset.builtIn + themes.filter { tp in
            ThemePreset.builtIn.contains { $0.id == tp.id } == false
        }
        cachedThemes = result
        return result
    }

    func saveTheme(_ theme: ThemePreset) {
        let themeId = theme.id
        let descriptor = FetchDescriptor<ThemeRecord>(predicate: #Predicate { $0.id == themeId })
        if let existing = try? context.fetch(descriptor).first {
            Self.apply(theme, to: existing)
        } else {
            context.insert(Self.toThemeRecord(theme))
        }
        try? context.save()
        cachedThemes = nil
    }

    func deleteTheme(id: UUID) {
        let themeId = id
        let descriptor = FetchDescriptor<ThemeRecord>(predicate: #Predicate { $0.id == themeId })
        if let record = try? context.fetch(descriptor).first, record.isBuiltIn == false {
            context.delete(record)
            try? context.save()
            cachedThemes = nil
        }
    }

    func loadAllSources() -> [BookSource] {
        let descriptor = FetchDescriptor<BookSourceRecord>(sortBy: [SortDescriptor(\.name)])
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map { Self.toBookSource($0) }
    }

    func saveSource(_ source: BookSource) {
        let sourceId = source.id
        let descriptor = FetchDescriptor<BookSourceRecord>(predicate: #Predicate { $0.id == sourceId })
        if let existing = try? context.fetch(descriptor).first {
            Self.apply(source, to: existing)
        } else {
            context.insert(Self.toRecord(source))
        }
        try? context.save()
    }

    func deleteSource(id: String) {
        let sourceId = id
        let descriptor = FetchDescriptor<BookSourceRecord>(predicate: #Predicate { $0.id == sourceId })
        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
    }

    private func fetchStatsRecord() -> ReadingStatsRecord? {
        let descriptor = FetchDescriptor<ReadingStatsRecord>(predicate: #Predicate { $0.key == "main" })
        return try? context.fetch(descriptor).first
    }

    private func createStatsRecord() -> ReadingStatsRecord {
        let record = ReadingStatsRecord(key: "main", dailySeconds: 0, readingDate: Date())
        context.insert(record)
        return record
    }

    private static func toBook(_ record: BookRecord) -> Book {
        let origin: BookOrigin
        switch record.originType {
        case "local":
            origin = .local(URL(fileURLWithPath: record.originPath ?? ""))
        case "online":
            origin = .online(sourceId: record.originSourceId ?? "", bookUrl: record.originBookUrl ?? "")
        default:
            origin = .local(URL(fileURLWithPath: record.originPath ?? ""))
        }

        return Book(
            id: record.id,
            title: record.title,
            author: record.author,
            origin: origin,
            lastReadPosition: ReadPosition(
                chapterIndex: record.chapterIndex,
                scrollOffset: record.scrollOffset,
                pageIndex: record.pageIndex
            ),
            addedAt: record.addedAt,
            lastReadAt: record.lastReadAt,
            totalReadingSeconds: record.totalReadingSeconds
        )
    }

    private static func toRecord(_ book: Book) -> BookRecord {
        switch book.origin {
        case .local(let url):
            return BookRecord(
                id: book.id, title: book.title, author: book.author,
                originType: "local", originPath: url.path, originSourceId: nil, originBookUrl: nil,
                chapterIndex: book.lastReadPosition.chapterIndex,
                scrollOffset: book.lastReadPosition.scrollOffset,
                pageIndex: book.lastReadPosition.pageIndex,
                addedAt: book.addedAt, lastReadAt: book.lastReadAt,
                totalReadingSeconds: book.totalReadingSeconds
            )
        case .online(let sourceId, let bookUrl):
            return BookRecord(
                id: book.id, title: book.title, author: book.author,
                originType: "online", originPath: nil, originSourceId: sourceId, originBookUrl: bookUrl,
                chapterIndex: book.lastReadPosition.chapterIndex,
                scrollOffset: book.lastReadPosition.scrollOffset,
                pageIndex: book.lastReadPosition.pageIndex,
                addedAt: book.addedAt, lastReadAt: book.lastReadAt,
                totalReadingSeconds: book.totalReadingSeconds
            )
        }
    }

    private static func apply(_ book: Book, to record: BookRecord) {
        record.title = book.title
        record.author = book.author
        switch book.origin {
        case .local(let url):
            record.originType = "local"
            record.originPath = url.path
            record.originSourceId = nil
            record.originBookUrl = nil
        case .online(let sourceId, let bookUrl):
            record.originType = "online"
            record.originPath = nil
            record.originSourceId = sourceId
            record.originBookUrl = bookUrl
        }
        record.chapterIndex = book.lastReadPosition.chapterIndex
        record.scrollOffset = book.lastReadPosition.scrollOffset
        record.pageIndex = book.lastReadPosition.pageIndex
        record.lastReadAt = book.lastReadAt
        record.totalReadingSeconds = book.totalReadingSeconds
    }

    private static func toBookSource(_ record: BookSourceRecord) -> BookSource {
        BookSource(
            id: record.id,
            name: record.name,
            url: record.url,
            searchUrl: record.searchUrl,
            isEnabled: record.isEnabled,
            searchRule: record.searchRule,
            titleRule: record.titleRule,
            authorRule: record.authorRule,
            bookUrlRule: record.bookUrlRule,
            introRule: record.introRule,
            chapterListRule: record.chapterListRule,
            chapterTitleRule: record.chapterTitleRule,
            chapterUrlRule: record.chapterUrlRule,
            contentRule: record.contentRule
        )
    }

    private static func toRecord(_ source: BookSource) -> BookSourceRecord {
        BookSourceRecord(
            id: source.id, name: source.name, url: source.url, searchUrl: source.searchUrl, isEnabled: source.isEnabled,
            searchRule: source.searchRule, titleRule: source.titleRule, authorRule: source.authorRule,
            bookUrlRule: source.bookUrlRule, introRule: source.introRule,
            chapterListRule: source.chapterListRule, chapterTitleRule: source.chapterTitleRule,
            chapterUrlRule: source.chapterUrlRule, contentRule: source.contentRule
        )
    }

    private static func apply(_ source: BookSource, to record: BookSourceRecord) {
        record.name = source.name
        record.url = source.url
        record.searchUrl = source.searchUrl
        record.isEnabled = source.isEnabled
        record.searchRule = source.searchRule
        record.titleRule = source.titleRule
        record.authorRule = source.authorRule
        record.bookUrlRule = source.bookUrlRule
        record.introRule = source.introRule
        record.chapterListRule = source.chapterListRule
        record.chapterTitleRule = source.chapterTitleRule
        record.chapterUrlRule = source.chapterUrlRule
        record.contentRule = source.contentRule
    }

    private static func toThemePreset(_ record: ThemeRecord) -> ThemePreset {
        ThemePreset(
            id: record.id,
            name: record.name,
            baseTheme: ReadingTheme(rawValue: record.baseThemeRaw) ?? .light,
            paperColorHex: record.paperColorHex,
            inkColorHex: record.inkColorHex,
            accentColorHex: record.accentColorHex,
            fontFamily: record.fontFamily,
            fontSize: record.fontSize,
            lineHeight: record.lineHeight,
            isBuiltIn: record.isBuiltIn
        )
    }

    private static func toThemeRecord(_ theme: ThemePreset) -> ThemeRecord {
        ThemeRecord(
            id: theme.id, name: theme.name, baseThemeRaw: theme.baseTheme.rawValue,
            paperColorHex: theme.paperColorHex, inkColorHex: theme.inkColorHex, accentColorHex: theme.accentColorHex,
            fontFamily: theme.fontFamily, fontSize: theme.fontSize, lineHeight: theme.lineHeight,
            isBuiltIn: theme.isBuiltIn
        )
    }

    private static func apply(_ theme: ThemePreset, to record: ThemeRecord) {
        record.name = theme.name
        record.baseThemeRaw = theme.baseTheme.rawValue
        record.paperColorHex = theme.paperColorHex
        record.inkColorHex = theme.inkColorHex
        record.accentColorHex = theme.accentColorHex
        record.fontFamily = theme.fontFamily
        record.fontSize = theme.fontSize
        record.lineHeight = theme.lineHeight
    }
}
