import Foundation
import Testing
@testable import NovelReaderApp

struct BookCoverResolverTests {
    @Test func findsCoverWithSameBaseNameAsLocalTextFile() throws {
        let directory = try temporaryDirectory()
        let textURL = directory.appendingPathComponent("寂静杀戮.txt")
        let coverURL = directory.appendingPathComponent("寂静杀戮.jpg")
        try "正文".write(to: textURL, atomically: true, encoding: .utf8)
        try Data([0xff, 0xd8, 0xff]).write(to: coverURL)

        let book = Book(title: "寂静杀戮.txt", origin: .local(textURL))

        #expect(BookCoverResolver.localCoverURL(for: book) == coverURL)
    }

    @Test func ignoresOnlineBooks() {
        let book = Book(title: "在线书", origin: .online(sourceId: "s1", bookUrl: "https://example.com/book"))

        #expect(BookCoverResolver.localCoverURL(for: book) == nil)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
