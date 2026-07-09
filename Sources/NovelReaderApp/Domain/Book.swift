import Foundation

struct Book: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var author: String?
    var origin: BookOrigin
    var lastReadPosition: ReadPosition
    var addedAt: Date
    var lastReadAt: Date?
    var totalReadingSeconds: Double

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        origin: BookOrigin,
        lastReadPosition: ReadPosition = ReadPosition(),
        addedAt: Date = Date(),
        lastReadAt: Date? = nil,
        totalReadingSeconds: Double = 0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.origin = origin
        self.lastReadPosition = lastReadPosition
        self.addedAt = addedAt
        self.lastReadAt = lastReadAt
        self.totalReadingSeconds = totalReadingSeconds
    }

    func readingProgress(totalChapters: Int) -> Double {
        guard totalChapters > 0 else { return 0 }
        let ratio = Double(lastReadPosition.chapterIndex + 1) / Double(totalChapters)
        return min(max(ratio, 0), 1)
    }
}

enum BookOrigin: Equatable, Sendable {
    case local(URL)
    case online(sourceId: String, bookUrl: String)
}

struct ReadPosition: Equatable, Sendable {
    var chapterIndex: Int
    var scrollOffset: Double
    var pageIndex: Int?

    init(chapterIndex: Int = 0, scrollOffset: Double = 0, pageIndex: Int? = nil) {
        self.chapterIndex = chapterIndex
        self.scrollOffset = scrollOffset
        self.pageIndex = pageIndex
    }
}
