import Foundation
import SwiftUI

enum ReadingMode: String, CaseIterable, Equatable {
    case scroll
    case paged

    var label: String {
        switch self {
        case .scroll: "滚动"
        case .paged: "分页"
        }
    }
}

struct PageRange: Equatable {
    let start: Int
    let end: Int
}

struct PaginationCalculator {
    func paginate(text: String, fontSize: Double, lineHeight: Double, viewportWidth: CGFloat, viewportHeight: CGFloat) -> [PageRange] {
        let totalLength = text.count

        guard totalLength > 0 else {
            return [PageRange(start: 0, end: 0)]
        }

        let charsPerLine = max(1, Int(viewportWidth / (fontSize * 0.55)))
        let linesPerPage = max(1, Int(viewportHeight / (fontSize * lineHeight)))
        let charsPerPage = max(1, charsPerLine * linesPerPage)

        var pages: [PageRange] = []
        var offset = 0

        while offset < totalLength {
            let remaining = totalLength - offset
            let pageLength = min(charsPerPage, remaining)
            let pageEnd = offset + pageLength

            pages.append(PageRange(start: offset, end: pageEnd))
            offset = pageEnd
        }

        if pages.isEmpty {
            pages.append(PageRange(start: 0, end: totalLength))
        }

        return pages
    }

    func pageContent(text: String, range: PageRange) -> String {
        guard range.start < text.count else { return "" }
        let endOffset = min(range.end, text.count)
        let start = text.index(text.startIndex, offsetBy: range.start)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        return String(text[start..<end])
    }
}
