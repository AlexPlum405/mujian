import Foundation

enum ChapterContentError: LocalizedError, Equatable {
    case notAvailable
    case sourceUnavailable
    case chapterNotFound
    case paused

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "这一章还没有加载。"
        case .sourceUnavailable:
            "找不到对应的书源。"
        case .chapterNotFound:
            "找不到这一章。"
        case .paused:
            "已暂停加载。"
        }
    }
}

@MainActor
protocol ChapterContentProvider: AnyObject {
    func content(for bookId: UUID, chapterIndex: Int) async throws -> String
    func isCached(bookId: UUID, chapterIndex: Int) -> Bool
    func pause()
    func resume()
}

@MainActor
final class LocalChapterContentProvider: ChapterContentProvider {
    private let documentProvider: () -> NovelDocument?

    init(documentProvider: @escaping () -> NovelDocument? = { nil }) {
        self.documentProvider = documentProvider
    }

    func content(for bookId: UUID, chapterIndex: Int) async throws -> String {
        guard let document = documentProvider(),
              document.chapters.indices.contains(chapterIndex) else {
            throw ChapterContentError.notAvailable
        }
        return document.chapters[chapterIndex].body
    }

    func isCached(bookId: UUID, chapterIndex: Int) -> Bool {
        guard let document = documentProvider() else { return false }
        return document.chapters.indices.contains(chapterIndex)
    }

    func pause() {}
    func resume() {}
}

@MainActor
final class OnlineChapterContentProvider: ChapterContentProvider {
    private let engine: BookSourceEngine
    private let sourcesProvider: () -> [BookSource]
    private let bookLookup: (UUID) -> Book?
    private let cacheDirectory: URL
    private var chapterListCache: [UUID: [OnlineChapter]] = [:]

    init(
        engine: BookSourceEngine,
        sourcesProvider: @escaping () -> [BookSource],
        bookLookup: @escaping (UUID) -> Book?,
        cacheDirectory: URL
    ) {
        self.engine = engine
        self.sourcesProvider = sourcesProvider
        self.bookLookup = bookLookup
        self.cacheDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func content(for bookId: UUID, chapterIndex: Int) async throws -> String {
        if let cached = cachedContent(for: bookId, chapterIndex: chapterIndex) {
            return cached
        }

        guard let book = bookLookup(bookId),
              case .online(let sourceId, _) = book.origin,
              let source = sourcesProvider().first(where: { $0.id == sourceId }) else {
            throw ChapterContentError.sourceUnavailable
        }

        let chapters = try await chapterList(for: bookId, book: book, source: source)
        guard chapters.indices.contains(chapterIndex) else {
            throw ChapterContentError.chapterNotFound
        }

        let raw = try await engine.loadChapterContent(chapterUrl: chapters[chapterIndex].url, source: source)
        let cleaned = OnlineChapterContentProvider.clean(raw)
        saveCache(cleaned, for: bookId, chapterIndex: chapterIndex)
        return cleaned
    }

    func isCached(bookId: UUID, chapterIndex: Int) -> Bool {
        cachedContent(for: bookId, chapterIndex: chapterIndex) != nil
    }

    func pause() {
        engine.pause()
    }

    func resume() {
        engine.resume()
    }

    func preloadChapterList(_ chapters: [OnlineChapter], for bookId: UUID) {
        chapterListCache[bookId] = chapters
    }

    func chapterList(for bookId: UUID, book: Book, source: BookSource) async throws -> [OnlineChapter] {
        if let cached = chapterListCache[bookId] {
            return cached
        }
        let chapters: [OnlineChapter]
        if case .online(_, let bookUrl) = book.origin {
            chapters = try await engine.loadChapterList(bookUrl: bookUrl, source: source)
        } else {
            chapters = []
        }
        chapterListCache[bookId] = chapters
        return chapters
    }

    private func cacheURL(for bookId: UUID, chapterIndex: Int) -> URL {
        cacheDirectory
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent("\(chapterIndex).txt")
    }

    private func cachedContent(for bookId: UUID, chapterIndex: Int) -> String? {
        let url = cacheURL(for: bookId, chapterIndex: chapterIndex)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func saveCache(_ content: String, for bookId: UUID, chapterIndex: Int) {
        let url = cacheURL(for: bookId, chapterIndex: chapterIndex)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    static func clean(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }
}
