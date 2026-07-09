import Foundation
import SwiftSoup

enum LegadoSelector {
    private static let knownAttributes: Set<String> = [
        "text", "textNodes", "html", "innerHTML", "outerHTML",
        "href", "src", "title", "content", "value", "name",
        "id", "class", "alt", "srcset"
    ]

    static func isLegadoSelector(_ rule: String) -> Bool {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("class.") || trimmed.hasPrefix("id.") || trimmed.hasPrefix("tag.")
    }

    static func toCSS(_ rule: String) -> String {
        parseSelector(rule).css
    }

    static func parseSelector(_ rule: String) -> (css: String, index: (Int, Int)?) {
        var working = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        var indexRange: (Int, Int)?

        if let bangRange = working.range(of: "!") {
            let before = String(working[..<bangRange.lowerBound])
            let after = String(working[bangRange.upperBound...])
            if let parsed = parseIndex(after) {
                indexRange = parsed
                working = before.trimmingCharacters(in: .whitespacesAndNewlines)
                if working.hasSuffix("@") {
                    working = String(working.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        let segments = working.split(separator: Character("@")).map(String.init)
        var cssParts: [String] = []
        for (offset, segment) in segments.enumerated() {
            let converted = convertSegment(segment)
            cssParts.append(converted.css)
            if offset == segments.count - 1, let segIndex = converted.index, indexRange == nil {
                indexRange = segIndex
            }
        }

        let css = cssParts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        return (css, indexRange)
    }

    static func selectText(html: String, selector: String) -> String {
        let (css, attr, index) = parseFullRule(selector)
        guard css.isEmpty == false else { return "" }
        do {
            let doc = try SwiftSoup.parse(html)
            let elements = try doc.select(css)
            let resolved = applyIndex(elements, index: index)
            guard let target = resolved.first else { return "" }
            return extractAttr(from: target, attr: attr)
        } catch {
            return ""
        }
    }

    static func selectTextList(html: String, selector: String) -> [String] {
        let (css, attr, index) = parseFullRule(selector)
        guard css.isEmpty == false else { return [] }
        do {
            let doc = try SwiftSoup.parse(html)
            let elements = try doc.select(css)
            let resolved = applyIndex(elements, index: index)
            return resolved.map { extractAttr(from: $0, attr: attr) }
        } catch {
            return []
        }
    }

    static func selectTextFromElement(_ element: Element, selector: String) -> String {
        let (css, attr, index) = parseFullRule(selector)
        guard css.isEmpty == false else { return "" }
        do {
            let elements = try element.select(css)
            let resolved = applyIndex(elements, index: index)
            guard let target = resolved.first else { return "" }
            return extractAttr(from: target, attr: attr)
        } catch {
            return ""
        }
    }

    static func selectAttrFromElement(_ element: Element, selector: String, attr: String) -> String {
        let (css, _, index) = parseFullRule(selector)
        guard css.isEmpty == false else { return "" }
        do {
            let elements = try element.select(css)
            let resolved = applyIndex(elements, index: index)
            guard let target = resolved.first else { return "" }
            return try target.attr(attr)
        } catch {
            return ""
        }
    }

    private static func parseFullRule(_ rule: String) -> (css: String, attr: String, index: (Int, Int)?) {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        var working = trimmed
        var attr = "text"

        let segments = trimmed.split(separator: Character("@")).map(String.init)
        if segments.count >= 2, let last = segments.last, knownAttributes.contains(last) {
            attr = last
            working = segments.dropLast().joined(separator: "@")
        }

        let (css, index) = parseSelector(working)
        return (css, attr, index)
    }

    private static func parseIndex(_ text: String) -> (Int, Int)? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else { return nil }

        let allowed: Set<Character> = Set("-0123456789:")
        var endIndex = cleaned.startIndex
        while endIndex < cleaned.endIndex, allowed.contains(cleaned[endIndex]) {
            endIndex = cleaned.index(after: endIndex)
        }
        let token = String(cleaned[..<endIndex])
        guard token.isEmpty == false else { return nil }

        if token.contains(":") {
            let parts = token.split(separator: Character(":"), maxSplits: 1).map(String.init)
            guard parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]) else { return nil }
            return (start, end)
        }
        guard let value = Int(token) else { return nil }
        return (value, value)
    }

    private static func convertSegment(_ segment: String) -> (css: String, index: (Int, Int)?) {
        var s = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        var indexRange: (Int, Int)?

        if s.hasPrefix("class.") {
            s = "." + String(s.dropFirst("class.".count))
        } else if s.hasPrefix("id.") {
            s = "#" + String(s.dropFirst("id.".count))
        } else if s.hasPrefix("tag.") {
            s = String(s.dropFirst("tag.".count))
        }

        if let dotRange = s.range(of: ".", options: .backwards) {
            let after = String(s[dotRange.upperBound...])
            let before = String(s[..<dotRange.lowerBound])
            if before.isEmpty == false, let value = Int(after) {
                indexRange = (value, value)
                s = before
            }
        }

        return (s, indexRange)
    }

    private static func applyIndex(_ elements: Elements, index: (Int, Int)?) -> [Element] {
        let array = elements.array()
        guard let (start, end) = index else { return array }
        if start == end {
            let resolved = start < 0 ? array.count + start : start
            if resolved >= 0 && resolved < array.count {
                return [array[resolved]]
            }
            return []
        }
        let from = max(0, start < 0 ? array.count + start : start)
        let to = min(array.count, end < 0 ? array.count + end + 1 : end + 1)
        if from >= to { return [] }
        return Array(array[from..<to])
    }

    private static func extractAttr(from element: Element, attr: String) -> String {
        do {
            if attr.isEmpty || attr == "text" {
                return try element.text()
            }
            if attr == "html" || attr == "innerHTML" {
                return try element.html()
            }
            if attr == "outerHTML" {
                return try element.outerHtml()
            }
            return try element.attr(attr)
        } catch {
            return ""
        }
    }
}
