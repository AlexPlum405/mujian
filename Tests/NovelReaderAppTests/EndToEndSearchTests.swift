import Testing
import Foundation
@testable import NovelReaderApp

@MainActor
@Suite(.serialized)
struct EndToEndSearchTests {
    @Test func searchSilentSlaughterVia22biqu() async {
        guard Self.runsLiveBookSourceTests else { return }

        let source = BookSource(
            id: "test-22biqu",
            name: "笔趣阁22",
            url: "https://www.22biqu.com/",
            searchUrl: "https://www.22biqu.com/ss/,{\"method\":\"POST\",\"body\":\"searchkey={{searchKey}}&Submit=搜索\"}",
            isEnabled: true,
            searchRule: "css:ul.txt-list li",
            titleRule: "span.s2 a@text",
            authorRule: "span.s4@text",
            bookUrlRule: "span.s2 a@href",
            introRule: "",
            chapterListRule: "css:li > a",
            chapterTitleRule: "@text",
            chapterUrlRule: "@href",
            contentRule: "css:#content@text"
        )

        let engine = LegadoBookSourceEngine()

        var results: [OnlineSearchResult] = []
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            results = await engine.search(query: "寂静杀戮", sources: [source])
            if results.isEmpty == false { break }
        }

        print("\n========== 搜索结果 ==========")
        print("结果数量: \(results.count)")
        for r in results {
            print("  书名: \(r.title), 作者: \(r.author ?? "nil"), URL: \(r.bookUrl)")
        }
        print("==============================\n")

        #expect(results.isEmpty == false, "应该搜到结果")
        #expect(results.contains { $0.title.contains("寂静") }, "结果应包含寂静杀戮")
    }

    @Test func imported22BiquSourceSelectorsFallbackToTxtList() throws {
        let source = BookSource(
            id: "https://www.22biqu.com/",
            name: "笔趣阁22",
            url: "https://www.22biqu.com/",
            searchUrl: "https://www.22biqu.com/ss/,{\"method\":\"POST\",\"body\":\"searchkey={{searchKey}}&Submit=搜索\"}",
            isEnabled: true,
            searchRule: "body > div.container > div > div > ul > li",
            titleRule: "span.s2 > a@text",
            authorRule: "span.s4@text",
            bookUrlRule: "span.s2 > a@href",
            introRule: "",
            chapterListRule: "div:nth-child(4) > ul > li > a",
            chapterTitleRule: "@text",
            chapterUrlRule: "@href",
            contentRule: "#content@text"
        )
        let html = """
        <html>
          <body>
            <main class="container">
              <ul class="txt-list txt-list-row5">
                <li>
                  <span class="s2"><a href="/biqu36410/">寂静杀戮</a></span>
                  <span class="s4">熊狼狗</span>
                </li>
              </ul>
            </main>
          </body>
        </html>
        """

        let engine = LegadoBookSourceEngine()
        let results = try engine.parseSearchResultsForTest(
            html: html,
            source: source,
            ruleType: SourceRuleType.detect(source.searchRule) ?? .unknown
        )

        #expect(results.contains { $0.title.contains("寂静杀戮") }, "导入的旧选择器也应该搜到寂静杀戮")
    }

    @Test func loadChapterListForSilentSlaughter() async throws {
        guard Self.runsLiveBookSourceTests else { return }

        let source = BookSource(
            id: "test-22biqu",
            name: "笔趣阁22",
            url: "https://www.22biqu.com/",
            searchUrl: "",
            searchRule: "",
            titleRule: "",
            authorRule: "",
            bookUrlRule: "",
            introRule: "",
            chapterListRule: "css:li > a",
            chapterTitleRule: "@text",
            chapterUrlRule: "@href",
            contentRule: "css:#content@text"
        )

        let engine = LegadoBookSourceEngine()
        let chapters = try await engine.loadChapterList(
            bookUrl: "https://www.22biqu.com/biqu36410/",
            source: source
        )

        print("\n========== 章节列表 ==========")
        print("章节数量: \(chapters.count)")
        for c in chapters.prefix(3) {
            print("  \(c.title) -> \(c.url)")
        }
        if chapters.count > 6 {
            print("  ...")
            for c in chapters.suffix(3) {
                print("  \(c.title) -> \(c.url)")
            }
        }
        print("==============================\n")

        #expect(chapters.isEmpty == false, "应该有章节")
        #expect(chapters.count > 200, "应该能跨目录分页加载，不应只停在前200章")
    }

    @Test func loadChapterContent() async throws {
        guard Self.runsLiveBookSourceTests else { return }

        let source = BookSource(
            id: "test-22biqu",
            name: "笔趣阁22",
            url: "https://www.22biqu.com/",
            searchUrl: "",
            searchRule: "",
            titleRule: "",
            authorRule: "",
            bookUrlRule: "",
            introRule: "",
            chapterListRule: "",
            chapterTitleRule: "",
            chapterUrlRule: "",
            contentRule: "css:#content@text"
        )

        let engine = LegadoBookSourceEngine()
        let content = try await engine.loadChapterContent(
            chapterUrl: "https://www.22biqu.com/biqu36410/20473200.html",
            source: source
        )

        print("\n========== 正文内容 ==========")
        print("正文长度: \(content.count) 字符")
        let lines = content.split(separator: "\n").map(String.init)
        print("行数: \(lines.count)")
        for line in lines.prefix(5) {
            print("  \(line.prefix(80))")
        }
        print("==============================\n")

        #expect(content.isEmpty == false, "正文不应为空")
        #expect(content.count > 100, "正文应该有实质内容")
    }

    @Test func publicDomainVerifiedSourcesSmokeTest() async throws {
        guard Self.runsLivePublicSourceTests else { return }

        let sources = try Self.loadPublicDomainVerifiedSources()
        #expect(sources.count == 9)

        let engine = LegadoBookSourceEngine()

        let zhSource = try #require(sources.first { $0.name.contains("维基文库中文") })
        let zhResults = await engine.search(query: "紅樓夢", sources: [zhSource])
        #expect(zhResults.contains { $0.title.contains("紅樓夢") || $0.title.contains("红楼梦") })
        let redChapters = try await engine.loadChapterList(
            bookUrl: "https://zh.wikisource.org/wiki/%E7%B4%85%E6%A8%93%E5%A4%A2",
            source: zhSource
        )
        #expect(redChapters.count >= 100)
        let redContent = try await engine.loadChapterContent(chapterUrl: redChapters[0].url, source: zhSource)
        #expect(redContent.count > 500)

        let enSource = try #require(sources.first { $0.name.contains("Wikisource English") })
        let enResults = await engine.search(query: "Pride and Prejudice 1817", sources: [enSource])
        let pride = try #require(enResults.first { $0.title == "Pride and Prejudice (1817)" })
        let prideChapters = try await engine.loadChapterList(bookUrl: pride.bookUrl, source: enSource)
        #expect(prideChapters.count >= 60)
        let prideContent = try await engine.loadChapterContent(chapterUrl: prideChapters[0].url, source: enSource)
        #expect(prideContent.count > 500)

        let aozoraSource = try #require(sources.first { $0.name.contains("芥川") })
        let aozoraResults = await engine.search(query: "羅生門", sources: [aozoraSource])
        let rashomon = try #require(aozoraResults.first { $0.title == "羅生門" && $0.bookUrl.contains("card127") })
        let rashomonChapters = try await engine.loadChapterList(bookUrl: rashomon.bookUrl, source: aozoraSource)
        #expect(rashomonChapters.isEmpty == false)
        let rashomonContent = try await engine.loadChapterContent(chapterUrl: rashomonChapters[0].url, source: aozoraSource)
        #expect(rashomonContent.count > 500)
    }

    private static var runsLiveBookSourceTests: Bool {
        ProcessInfo.processInfo.environment["RUN_LIVE_BOOK_SOURCE_TESTS"] == "1"
    }

    private static var runsLivePublicSourceTests: Bool {
        ProcessInfo.processInfo.environment["RUN_LIVE_PUBLIC_SOURCE_TESTS"] == "1"
    }

    private static func loadPublicDomainVerifiedSources() throws -> [BookSource] {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("book-sources/public-domain-verified-sources.json")
        let data = try Data(contentsOf: url)
        return try BookSource.decode(from: data)
    }
}
