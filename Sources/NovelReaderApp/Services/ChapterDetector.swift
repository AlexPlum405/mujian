import Foundation

struct ChapterDetector {
    var lastCustomPatternError: String?

    private static let chineseNumberedChapterRegex = try! NSRegularExpression(
        pattern: #"^\s*第\s*[0-9零〇○一二两三四五六七八九十百千万]+\s*[章节回部集卷]\b.*$"#
    )
    private static let volumeRegex = try! NSRegularExpression(
        pattern: #"^\s*卷\s*[0-9零〇○一二两三四五六七八九十百千万]+.*$"#
    )
    private static let structureTitleRegex = try! NSRegularExpression(
        pattern: #"^\s*(序章|楔子|番外|尾声|后记|前言)(\s*[·:：-].*)?\s*$"#
    )
    private static let englishChapterRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"^\s*chapter\s+[0-9ivxlcdm]+(\b|[\s:：.-]).*$"#,
            options: [.caseInsensitive]
        )
    }()

    func detectChapters(in text: String, customPattern: String? = nil) -> [NovelChapter] {
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedText.components(separatedBy: "\n")
        let customRegex = compiledCustomRegex(from: customPattern)
        let matches = lines.enumerated().compactMap { index, line -> ChapterMatch? in
            let title = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isChapterTitle(title, customRegex: customRegex) else { return nil }
            return ChapterMatch(title: title, lineIndex: index)
        }

        guard matches.isEmpty == false else {
            return [.fallback(body: normalizedText)]
        }

        return matches.enumerated().map { chapterIndex, match in
            let nextLineIndex = matches.indices.contains(chapterIndex + 1)
                ? matches[chapterIndex + 1].lineIndex
                : lines.count
            let bodyStart = min(match.lineIndex + 1, lines.count)
            let bodyLines = bodyStart < nextLineIndex ? Array(lines[bodyStart..<nextLineIndex]) : []
            let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            return NovelChapter(
                id: chapterIndex,
                title: match.title,
                body: body.isEmpty ? match.title : body,
                lineNumber: match.lineIndex + 1
            )
        }
    }

    mutating func refreshCustomPatternError(_ pattern: String?) {
        lastCustomPatternError = nil
        guard let pattern = pattern?.trimmingCharacters(in: .whitespacesAndNewlines),
              pattern.isEmpty == false else {
            return
        }
        do {
            _ = try NSRegularExpression(pattern: pattern)
        } catch {
            lastCustomPatternError = "正则语法错误"
        }
    }

    private func compiledCustomRegex(from customPattern: String?) -> NSRegularExpression? {
        guard let pattern = customPattern?.trimmingCharacters(in: .whitespacesAndNewlines),
              pattern.isEmpty == false else {
            return nil
        }
        return try? NSRegularExpression(pattern: pattern)
    }

    private func isChapterTitle(_ title: String, customRegex: NSRegularExpression?) -> Bool {
        guard title.isEmpty == false, title.count <= 60 else {
            return false
        }

        let range = NSRange(title.startIndex..., in: title)
        if let customRegex, customRegex.firstMatch(in: title, range: range) != nil {
            return true
        }
        return Self.chineseNumberedChapterRegex.firstMatch(in: title, range: range) != nil
            || Self.volumeRegex.firstMatch(in: title, range: range) != nil
            || Self.structureTitleRegex.firstMatch(in: title, range: range) != nil
            || Self.englishChapterRegex.firstMatch(in: title, range: range) != nil
    }
}

private struct ChapterMatch {
    let title: String
    let lineIndex: Int
}
