import Testing
import Foundation
@testable import NovelReaderApp

@MainActor
struct EndToEndSearchTests {
    @Test func searchSilentSlaughterVia22biqu() async {
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

    @Test func loadChapterListForSilentSlaughter() async throws {
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
        #expect(chapters.count > 10, "应该有超过10章")
    }

    @Test func loadChapterContent() async throws {
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
}
