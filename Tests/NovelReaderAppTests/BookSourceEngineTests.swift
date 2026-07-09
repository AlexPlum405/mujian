import Foundation
import Testing
@testable import NovelReaderApp

@MainActor
@Suite(.serialized)
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

    @Test func loadChapterListFollowsIndexPagination() async throws {
        let page1 = """
        <html>
          <body>
            <ul class="section-list latest">
              <li><a href="/book/c4.html">第004章 终</a></li>
            </ul>
            <ul class="section-list">
              <li><a href="/book/c1.html">第001章 起</a></li>
              <li><a href="/book/c2.html">第002章 承</a></li>
            </ul>
            <div class="index-container">
              <select id="indexselect">
                <option value="/book/" selected>1 - 2章</option>
                <option value="/book/2/">3 - 4章</option>
              </select>
            </div>
          </body>
        </html>
        """
        let page2 = """
        <html>
          <body>
            <ul class="section-list">
              <li><a href="/book/c3.html">第003章 转</a></li>
              <li><a href="/book/c4.html">第004章 终</a></li>
            </ul>
          </body>
        </html>
        """

        MockURLProtocol.responses = [
            URL(string: "https://example.com/book/")!: page1.data(using: .utf8)!,
            URL(string: "https://example.com/book/2/")!: page2.data(using: .utf8)!
        ]
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let engine = LegadoBookSourceEngine(session: URLSession(configuration: configuration))

        let chapters = try await engine.loadChapterList(bookUrl: "https://example.com/book/", source: makeSource(
            chapterListRule: ".section-list a",
            chapterTitleRule: "@text",
            chapterUrlRule: "@href"
        ))

        #expect(chapters.map(\.title) == ["第001章 起", "第002章 承", "第003章 转", "第004章 终"])
        #expect(chapters.map(\.url) == [
            "https://example.com/book/c1.html",
            "https://example.com/book/c2.html",
            "https://example.com/book/c3.html",
            "https://example.com/book/c4.html"
        ])
    }

    @Test func searchResolvesRelativeBookURLsAgainstSearchPage() throws {
        let html = """
        <html>
          <body>
            <ol>
              <li><a href="../cards/000879/card127.html">羅生門</a></li>
            </ol>
          </body>
        </html>
        """
        let source = makeSource(
            url: "https://www.aozora.gr.jp/",
            chapterListRule: "a",
            chapterTitleRule: "@text",
            chapterUrlRule: "@href"
        )
        let engine = LegadoBookSourceEngine()

        let results = try engine.parseSearchResultsForTest(
            html: html,
            source: BookSource(
                id: source.id,
                name: source.name,
                url: source.url,
                searchUrl: "https://www.aozora.gr.jp/index_pages/person879.html",
                searchRule: "ol li",
                titleRule: "a@text",
                authorRule: "",
                bookUrlRule: "a@href",
                introRule: "",
                chapterListRule: source.chapterListRule,
                chapterTitleRule: source.chapterTitleRule,
                chapterUrlRule: source.chapterUrlRule,
                contentRule: source.contentRule
            ),
            ruleType: .css,
            baseURL: URL(string: "https://www.aozora.gr.jp/index_pages/person879.html")
        )

        #expect(results.count == 1)
        #expect(results[0].bookUrl == "https://www.aozora.gr.jp/cards/000879/card127.html")
    }

    @Test func loadChapterListResolvesRelativeChapterURLsAgainstBookPage() async throws {
        let html = """
        <html>
          <body>
            <a href="./files/127_15260.html">いますぐXHTML版で読む</a>
          </body>
        </html>
        """

        MockURLProtocol.responses = [
            URL(string: "https://www.aozora.gr.jp/cards/000879/card127.html")!: html.data(using: .utf8)!
        ]
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let engine = LegadoBookSourceEngine(session: URLSession(configuration: configuration))

        let chapters = try await engine.loadChapterList(
            bookUrl: "https://www.aozora.gr.jp/cards/000879/card127.html",
            source: makeSource(
                url: "https://www.aozora.gr.jp/",
                chapterListRule: "a[href*=\"/files/\"], a[href^=\"./files/\"]",
                chapterTitleRule: "@text",
                chapterUrlRule: "@href"
            )
        )

        #expect(chapters.map(\.url) == [
            "https://www.aozora.gr.jp/cards/000879/files/127_15260.html"
        ])
    }

    @Test func loadChapterListOrdersLatestBlockBeforeChineseNumberedChapters() async throws {
        let html = """
        <html>
          <body>
            <ul class="section-list latest">
              <li><a href="/book/c1941.html">第1941章 示秘指天机</a></li>
              <li><a href="/book/c1942.html">第1942章 图开紫气生</a></li>
              <li><a href="/book/c1943.html">第1943章 秘异破妄相</a></li>
              <li><a href="/book/c1944.html">第1944章 空冥落回音</a></li>
              <li><a href="/book/c1945.html">第1945章 立序理旧罪</a></li>
            </ul>
            <ul class="section-list">
              <li><a href="/book/c1.html">第一章 阳芝武毅</a></li>
              <li><a href="/book/c2.html">第二章 入考</a></li>
              <li><a href="/book/c3.html">第三章 前世今生皆为我</a></li>
              <li><a href="/book/c4.html">第四章 敌在己，障在心</a></li>
            </ul>
          </body>
        </html>
        """

        MockURLProtocol.responses = [
            URL(string: "https://example.com/book/")!: html.data(using: .utf8)!
        ]
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let engine = LegadoBookSourceEngine(session: URLSession(configuration: configuration))

        let chapters = try await engine.loadChapterList(bookUrl: "https://example.com/book/", source: makeSource(
            chapterListRule: ".section-list a",
            chapterTitleRule: "@text",
            chapterUrlRule: "@href"
        ))

        #expect(chapters.map(\.title).prefix(4) == [
            "第一章 阳芝武毅",
            "第二章 入考",
            "第三章 前世今生皆为我",
            "第四章 敌在己，障在心"
        ])
        #expect(chapters.map(\.title).suffix(2) == [
            "第1944章 空冥落回音",
            "第1945章 立序理旧罪"
        ])
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

    @Test func onlineChapterContentProviderRestoresParagraphsFromCollapsedChineseText() {
        let cleaned = OnlineChapterContentProvider.clean("　　第一段。　　第二段！　　第三段？")
        #expect(cleaned == "第一段。\n第二段！\n第三段？")
    }

    @Test func onlineChapterContentProviderBreaksVeryLongCollapsedChineseText() {
        let first = "第一段" + String(repeating: "内容", count: 70) + "。"
        let second = "第二段" + String(repeating: "内容", count: 70) + "。"
        let cleaned = OnlineChapterContentProvider.clean(first + second)

        #expect(cleaned.contains("。\n第二段"))
    }

    private func makeSource(
        id: String = "s1",
        name: String = "源一",
        url: String = "https://example.com",
        chapterListRule: String = ".chapters>li",
        chapterTitleRule: String = "a@text",
        chapterUrlRule: String = "a@href"
    ) -> BookSource {
        BookSource(
            id: id,
            name: name,
            url: url,
            searchUrl: "https://example.com/s?q={{searchKey}}",
            isEnabled: true,
            searchRule: ".item",
            titleRule: ".title@text",
            authorRule: ".author@text",
            chapterListRule: chapterListRule,
            chapterTitleRule: chapterTitleRule,
            chapterUrlRule: chapterUrlRule,
            contentRule: "#content@text"
        )
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [URL: Data] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let data = Self.responses[url],
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
