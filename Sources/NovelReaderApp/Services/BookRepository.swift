import Foundation

@MainActor
protocol BookRepository: AnyObject {
    func loadAllBooks() -> [Book]
    func saveBook(_ book: Book)
    func deleteBook(id: UUID)

    func loadReadPosition(for bookId: UUID) -> ReadPosition?
    func saveReadPosition(_ position: ReadPosition, for bookId: UUID)

    func loadReadingSeconds(for bookId: UUID) -> Double
    func addReadingSeconds(_ seconds: Double, for bookId: UUID)

    func loadDailyReadingSeconds() -> Double
    func saveDailyReadingSeconds(_ seconds: Double)

    func loadReadingDate() -> Date?
    func saveReadingDate(_ date: Date)

    func loadAllThemes() -> [ThemePreset]
    func saveTheme(_ theme: ThemePreset)
    func deleteTheme(id: UUID)

    func loadAllSources() -> [BookSource]
    func saveSource(_ source: BookSource)
    func deleteSource(id: String)
}

@MainActor
final class InMemoryBookRepository: BookRepository {
    private var books: [UUID: Book] = [:]
    private var dailySeconds: Double = 0
    private var readingDate: Date?
    private var sources: [String: BookSource] = [:]

    func loadAllBooks() -> [Book] {
        books.values.sorted { $0.addedAt > $1.addedAt }
    }

    func saveBook(_ book: Book) {
        books[book.id] = book
    }

    func deleteBook(id: UUID) {
        books.removeValue(forKey: id)
    }

    func loadReadPosition(for bookId: UUID) -> ReadPosition? {
        books[bookId]?.lastReadPosition
    }

    func saveReadPosition(_ position: ReadPosition, for bookId: UUID) {
        books[bookId]?.lastReadPosition = position
    }

    func loadReadingSeconds(for bookId: UUID) -> Double {
        books[bookId]?.totalReadingSeconds ?? 0
    }

    func addReadingSeconds(_ seconds: Double, for bookId: UUID) {
        books[bookId]?.totalReadingSeconds += seconds
    }

    func loadDailyReadingSeconds() -> Double {
        dailySeconds
    }

    func saveDailyReadingSeconds(_ seconds: Double) {
        dailySeconds = seconds
    }

    func loadReadingDate() -> Date? {
        readingDate
    }

    func saveReadingDate(_ date: Date) {
        readingDate = date
    }

    private var themes: [ThemePreset] = ThemePreset.builtIn

    func loadAllThemes() -> [ThemePreset] {
        themes
    }

    func saveTheme(_ theme: ThemePreset) {
        if let index = themes.firstIndex(where: { $0.id == theme.id }) {
            themes[index] = theme
        } else {
            themes.append(theme)
        }
    }

    func deleteTheme(id: UUID) {
        themes.removeAll { $0.id == id && $0.isBuiltIn == false }
    }

    func loadAllSources() -> [BookSource] {
        sources.values.sorted { $0.name < $1.name }
    }

    func saveSource(_ source: BookSource) {
        sources[source.id] = source
    }

    func deleteSource(id: String) {
        sources.removeValue(forKey: id)
    }
}
