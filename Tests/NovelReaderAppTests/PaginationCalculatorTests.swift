import Testing
import Foundation
@testable import NovelReaderApp

@MainActor
struct PaginationCalculatorTests {
    private let calculator = PaginationCalculator()

    @Test func returnsOnePageForEmptyText() {
        let pages = calculator.paginate(
            text: "", fontSize: 17, lineHeight: 1.8,
            viewportWidth: 700, viewportHeight: 500
        )

        #expect(pages.count == 1)
        #expect(pages[0].start == 0)
        #expect(pages[0].end == 0)
    }

    @Test func returnsMultiplePagesForLongText() {
        let text = String(repeating: "这是一行测试文本内容。", count: 200)
        let pages = calculator.paginate(
            text: text, fontSize: 17, lineHeight: 1.8,
            viewportWidth: 700, viewportHeight: 500
        )

        #expect(pages.count > 1)
    }

    @Test func pageRangesAreContiguousAndNonOverlapping() {
        let text = String(repeating: "ABCD\n", count: 100)
        let pages = calculator.paginate(
            text: text, fontSize: 17, lineHeight: 1.8,
            viewportWidth: 400, viewportHeight: 300
        )

        for i in 0..<pages.count {
            #expect(pages[i].start <= pages[i].end)
            if i > 0 {
                #expect(pages[i].start == pages[i - 1].end || pages[i].start == pages[i - 1].end + 1)
            }
        }
    }

    @Test func largerFontSizeProducesMorePages() {
        let text = String(repeating: "测试文本", count: 100)
        let smallFontPages = calculator.paginate(
            text: text, fontSize: 12, lineHeight: 1.8,
            viewportWidth: 700, viewportHeight: 500
        )
        let largeFontPages = calculator.paginate(
            text: text, fontSize: 24, lineHeight: 1.8,
            viewportWidth: 700, viewportHeight: 500
        )

        #expect(largeFontPages.count >= smallFontPages.count)
    }

    @Test func largerViewportProducesFewerPages() {
        let text = String(repeating: "测试文本", count: 100)
        let smallViewportPages = calculator.paginate(
            text: text, fontSize: 17, lineHeight: 1.8,
            viewportWidth: 400, viewportHeight: 300
        )
        let largeViewportPages = calculator.paginate(
            text: text, fontSize: 17, lineHeight: 1.8,
            viewportWidth: 800, viewportHeight: 600
        )

        #expect(largeViewportPages.count <= smallViewportPages.count)
    }
}
