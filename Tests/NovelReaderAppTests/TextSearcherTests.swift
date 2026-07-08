import Testing
@testable import NovelReaderApp

struct TextSearcherTests {
    @Test func matchesCaseInsensitively() {
        let searcher = TextSearcher()
        let chapters = [(index: 0, title: "第一章", body: "Hello World\nHELLO again")]

        let results = searcher.search(query: "hello", in: chapters)

        #expect(results.count == 2)
        #expect(results[0].lineNumber == 1)
        #expect(results[1].lineNumber == 2)
    }

    @Test func aggregatesResultsAcrossChapters() {
        let searcher = TextSearcher()
        let chapters = [
            (index: 0, title: "第一章", body: "关键词出现"),
            (index: 1, title: "第二章", body: "这里没有"),
            (index: 2, title: "第三章", body: "又有关键词")
        ]

        let results = searcher.search(query: "关键词", in: chapters)

        #expect(results.count == 2)
        #expect(results[0].chapterIndex == 0)
        #expect(results[0].chapterTitle == "第一章")
        #expect(results[1].chapterIndex == 2)
        #expect(results[1].chapterTitle == "第三章")
    }

    @Test func returnsEmptyForEmptyQuery() {
        let searcher = TextSearcher()
        let chapters = [(index: 0, title: "第一章", body: "一些内容")]

        let results = searcher.search(query: "", in: chapters)

        #expect(results.isEmpty)
    }

    @Test func returnsEmptyForWhitespaceOnlyQuery() {
        let searcher = TextSearcher()
        let chapters = [(index: 0, title: "第一章", body: "一些内容")]

        let results = searcher.search(query: "   \n  ", in: chapters)

        #expect(results.isEmpty)
    }

    @Test func previewIncludesContextAroundMatch() {
        let searcher = TextSearcher()
        let prefix = String(repeating: "前", count: 30)
        let suffix = String(repeating: "后", count: 30)
        let body = "\(prefix)目标\(suffix)"
        let chapters = [(index: 0, title: "第一章", body: body)]

        let results = searcher.search(query: "目标", in: chapters)

        #expect(results.count == 1)
        let preview = results[0].preview
        #expect(preview.hasPrefix("…"))
        #expect(preview.hasSuffix("…"))
        #expect(preview.contains("目标"))
        let inner = preview.replacingOccurrences(of: "…", with: "")
        #expect(inner.count == 42)
    }

    @Test func previewHasNoEllipsisWhenMatchNearStart() {
        let searcher = TextSearcher()
        let suffix = String(repeating: "后", count: 30)
        let body = "目标\(suffix)"
        let chapters = [(index: 0, title: "第一章", body: body)]

        let results = searcher.search(query: "目标", in: chapters)

        #expect(results.count == 1)
        let preview = results[0].preview
        #expect(preview.hasPrefix("…") == false)
        #expect(preview.hasSuffix("…"))
        #expect(preview.contains("目标"))
    }

    @Test func previewHasNoEllipsisWhenMatchNearEnd() {
        let searcher = TextSearcher()
        let prefix = String(repeating: "前", count: 30)
        let body = "\(prefix)目标"
        let chapters = [(index: 0, title: "第一章", body: body)]

        let results = searcher.search(query: "目标", in: chapters)

        #expect(results.count == 1)
        let preview = results[0].preview
        #expect(preview.hasPrefix("…"))
        #expect(preview.hasSuffix("…") == false)
        #expect(preview.contains("目标"))
    }

    @Test func assignsIncrementalIds() {
        let searcher = TextSearcher()
        let chapters = [
            (index: 0, title: "第一章", body: "匹配\n匹配\n匹配")
        ]

        let results = searcher.search(query: "匹配", in: chapters)

        #expect(results.count == 3)
        #expect(results.map(\.id) == [0, 1, 2])
        #expect(results.map(\.lineNumber) == [1, 2, 3])
    }

    @Test func reportsCorrectLineNumbers() {
        let searcher = TextSearcher()
        let chapters = [
            (index: 0, title: "第一章", body: "第一行\n第二行有关键词\n第三行")
        ]

        let results = searcher.search(query: "关键词", in: chapters)

        #expect(results.count == 1)
        #expect(results[0].lineNumber == 2)
    }

    @Test func returnsEmptyWhenNoChapterMatches() {
        let searcher = TextSearcher()
        let chapters = [
            (index: 0, title: "第一章", body: "这里没有目标词"),
            (index: 1, title: "第二章", body: "这里也没有")
        ]

        let results = searcher.search(query: "关键词", in: chapters)

        #expect(results.isEmpty)
    }
}
