import Foundation

struct SearchResultItem: Identifiable, Equatable {
    let id: Int
    let chapterIndex: Int
    let chapterTitle: String
    let lineNumber: Int
    let preview: String
}

struct TextSearcher {
    func search(query: String, in chapters: [(index: Int, title: String, body: String)]) -> [SearchResultItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return []
        }

        var results: [SearchResultItem] = []
        var nextId = 0

        for chapter in chapters {
            let lines = chapter.body.components(separatedBy: "\n")
            for (lineIndex, line) in lines.enumerated() {
                guard let matchRange = line.range(of: trimmedQuery, options: .caseInsensitive) else {
                    continue
                }

                let preview = makePreview(line: line, matchRange: matchRange)
                results.append(SearchResultItem(
                    id: nextId,
                    chapterIndex: chapter.index,
                    chapterTitle: chapter.title,
                    lineNumber: lineIndex + 1,
                    preview: preview
                ))
                nextId += 1
            }
        }

        return results
    }

    private func makePreview(line: String, matchRange: Range<String.Index>) -> String {
        let matchStart = line.distance(from: line.startIndex, to: matchRange.lowerBound)
        let matchEnd = line.distance(from: line.startIndex, to: matchRange.upperBound)
        let characters = Array(line)

        let prefixStart = max(0, matchStart - 20)
        let suffixEnd = min(characters.count, matchEnd + 20)

        var preview = ""
        if prefixStart > 0 {
            preview += "…"
        }
        preview += String(characters[prefixStart..<suffixEnd])
        if suffixEnd < characters.count {
            preview += "…"
        }
        return preview
    }
}
