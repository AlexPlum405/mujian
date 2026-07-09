import Foundation

enum OnlineContentFormatter {
    static func cleanHTML(_ html: String) -> String {
        var text = html

        text = replaceRegex(text, pattern: #"(?i)<br\s*/?>"#, with: "\n")
        text = replaceRegex(text, pattern: #"(?i)</(p|div|li|section|article|blockquote|h[1-6])\s*>"#, with: "\n")
        text = replaceRegex(text, pattern: #"(?i)<(p|div|li|section|article|blockquote|h[1-6])\b[^>]*>"#, with: "")
        text = replaceRegex(text, pattern: #"<[^>]+>"#, with: "")

        return cleanPlainText(text)
    }

    static func cleanPlainText(_ raw: String) -> String {
        var text = decodeEntities(raw)
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        text = replaceRegex(text, pattern: #"[　]{2,}"#, with: "\n")

        var paragraphs: [String] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.isEmpty == false else {
                continue
            }

            let restored = restoreCollapsedSentences(in: line)
            paragraphs.append(contentsOf: restored)
        }

        return paragraphs.joined(separator: "\n")
    }

    private static func restoreCollapsedSentences(in line: String) -> [String] {
        let sentenceEndings = line.filter { "。！？!?".contains($0) }.count
        guard line.count > 120, sentenceEndings >= 2 else {
            return [line]
        }

        let restored = replaceRegex(
            line,
            pattern: #"([。！？!?])(?=\S)"#,
            with: "$1\n"
        )

        return restored
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private static func decodeEntities(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&ensp;", with: " ")
            .replacingOccurrences(of: "&emsp;", with: "\n")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
            .replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
            .replacingOccurrences(of: "&lsquo;", with: "\u{2018}")
            .replacingOccurrences(of: "&rsquo;", with: "\u{2019}")
            .replacingOccurrences(of: "&hellip;", with: "\u{2026}")
            .replacingOccurrences(of: "&mdash;", with: "\u{2014}")
    }

    private static func replaceRegex(_ input: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: replacement)
    }
}
