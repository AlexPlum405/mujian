import Foundation
import Testing
@testable import NovelReaderApp

@MainActor
struct BookSourceEngineTests {
    @Test func decodesLegadoBookSourceArray() throws {
        let json = """
        [
          {
            "bookSourceUrl": "https://www.example.com",
            "bookSourceName": "示例书源",
            "enabled": true,
            "searchUrl": "https://www.example.com/search?q={{searchKey}}",
            "ruleSearch": { "bookList": ".result-list>.item", "name": ".title@text", "author": ".author@text" },
            "ruleToc": { "chapterList": ".chapter-list>li", "chapterName": "a@text", "chapterUrl": "a@href" },
            "ruleContent": { "content": "#content@text" }
          }
        ]
        """.data(using: .utf8)!

        let sources = try BookSource.decode(from: json)

        #expect(sources.count == 1)
        let source = sources[0]
        #expect(source.id == "https://www.example.com")
        #expect(source.name == "示例书源")
        #expect(source.isEnabled == true)
        #expect(source.searchRule == ".result-list>.item")
        #expect(source.titleRule == ".title@text")
        #expect(source.chapterListRule == ".chapter-list>li")
        #expect(source.contentRule == "#content@text")
    }

    @Test func decodesSingleBookSourceObjectWithMissingFields() throws {
        let json = """
        {
          "bookSourceUrl": "https://single.example.com",
          "bookSourceName": "单源",
          "searchUrl": "https://single.example.com/s?q={{key}}"
        }
        """.data(using: .utf8)!

        let sources = try BookSource.decode(from: json)

        #expect(sources.count == 1)
        #expect(sources[0].name == "单源")
        #expect(sources[0].isEnabled == true)
        #expect(sources[0].searchUrl == "https://single.example.com/s?q={{key}}")
    }

    @Test func rejectsInvalidBookSourceJSON() {
        let json = "not json".data(using: .utf8)!

        #expect(throws: BookSourceError.self) {
            try BookSource.decode(from: json)
        }
    }

    @Test func aggregatesSearchResultsAcrossSources() async {
        let engine = StubBookSourceEngine()
        engine.searchResults = [
            OnlineSearchResult(title: "书A", author: "甲", bookUrl: "https://a.example.com/1", sourceId: "s1", sourceName: "源一"),
            OnlineSearchResult(title: "书B", author: "乙", bookUrl: "https://b.example.com/1", sourceId: "s2", sourceName: "源二")
        ]

        let sources = [
            makeSource(id: "s1", name: "源一", url: "https://a.example.com"),
            makeSource(id: "s2", name: "源二", url: "https://b.example.com")
        ]

        let results = await engine.search(query: "测试", sources: sources)

        #expect(results.count == 2)
        #expect(engine.lastSearchQuery == "测试")
        #expect(Set(engine.lastSearchedSourceIds) == Set(["s1", "s2"]))
    }

    @Test func skipsDisabledSourcesInSearch() async {
        let engine = StubBookSourceEngine()
        engine.searchResults = [
            OnlineSearchResult(title: "书A", author: nil, bookUrl: "https://a.example.com/1", sourceId: "s1", sourceName: "源一")
        ]

        var disabled = makeSource(id: "s1", name: "源一", url: "https://a.example.com")
        disabled.isEnabled = false

        let results = await engine.search(query: "测试", sources: [disabled])

        #expect(results.isEmpty)
    }

    @Test func loadsChapterListFromStub() async throws {
        let engine = StubBookSourceEngine()
        engine.chapters = [
            OnlineChapter(title: "第一章", url: "https://example.com/c1"),
            OnlineChapter(title: "第二章", url: "https://example.com/c2")
        ]

        let chapters = try await engine.loadChapterList(bookUrl: "https://example.com/book", source: makeSource())

        #expect(chapters.count == 2)
        #expect(chapters[0].title == "第一章")
        #expect(engine.lastLoadedBookUrl == "https://example.com/book")
    }

    @Test func loadsChapterContentFromStub() async throws {
        let engine = StubBookSourceEngine()
        engine.content = "这是正文内容。"

        let content = try await engine.loadChapterContent(chapterUrl: "https://example.com/c1", source: makeSource())

        #expect(content == "这是正文内容。")
    }

    @Test func pauseBlocksContentLoading() async throws {
        let engine = StubBookSourceEngine()
        engine.content = "正文"
        engine.pause()

        #expect(engine.isPaused == true)
        #expect(engine.pauseCallCount == 1)

        await #expect(throws: BookSourceError.self) {
            try await engine.loadChapterContent(chapterUrl: "https://example.com/c1", source: makeSource())
        }
    }

    @Test func resumeRestoresContentLoading() async throws {
        let engine = StubBookSourceEngine()
        engine.content = "正文"
        engine.pause()
        engine.resume()

        #expect(engine.isPaused == false)
        #expect(engine.resumeCallCount == 1)

        let content = try await engine.loadChapterContent(chapterUrl: "https://example.com/c1", source: makeSource())
        #expect(content == "正文")
    }

    @Test func repositoryPersistsBookSources() {
        let repository = InMemoryBookRepository()
        let source = makeSource()

        repository.saveSource(source)
        #expect(repository.loadAllSources().count == 1)

        repository.deleteSource(id: source.id)
        #expect(repository.loadAllSources().isEmpty)
    }

    @Test func onlineChapterContentProviderCachesContent() async throws {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = StubBookSourceEngine()
        engine.chapters = [OnlineChapter(title: "第一章", url: "https://example.com/c1")]
        engine.content = "缓存正文"

        let bookId = UUID()
        let book = Book(title: "在线书", origin: .online(sourceId: "s1", bookUrl: "https://example.com/book"))
        let sources = [makeSource()]

        let provider = OnlineChapterContentProvider(
            engine: engine,
            sourcesProvider: { sources },
            bookLookup: { id in id == bookId ? book : nil },
            cacheDirectory: cacheDir
        )
        provider.preloadChapterList(engine.chapters, for: bookId)

        let content = try await provider.content(for: bookId, chapterIndex: 0)
        #expect(content == "缓存正文")
        #expect(provider.isCached(bookId: bookId, chapterIndex: 0))
    }

    @Test func onlineChapterContentProviderCleansContent() {
        let cleaned = OnlineChapterContentProvider.clean("  abc&nbsp;\n\n  def  \n  ")
        #expect(cleaned == "abc\ndef")
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
}
