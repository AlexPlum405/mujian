import Foundation

enum LegadoRuleParser {
    struct ParsedRule {
        var selector: String
        var jsCode: String?
        var replaceRegex: String?
        var replaceValue: String?
        var template: String?
    }

    static func parse(_ rule: String) -> ParsedRule {
        var main = rule
        var replaceRegex: String?
        var replaceValue: String?

        if let lastHashRange = main.range(of: "##", options: .backwards) {
            let afterLastHash = String(main[lastHashRange.upperBound...])
            let beforeLastHash = String(main[..<lastHashRange.lowerBound])

            if let secondLastHashRange = beforeLastHash.range(of: "##", options: .backwards) {
                replaceRegex = String(beforeLastHash[secondLastHashRange.upperBound...])
                replaceValue = afterLastHash
                main = String(beforeLastHash[..<secondLastHashRange.lowerBound])
            } else {
                replaceRegex = afterLastHash
                replaceValue = nil
                main = beforeLastHash
            }
        }

        var selector = main
        var jsCode: String?

        let lowerMain = main.lowercased()
        if lowerMain.hasPrefix("js:") {
            jsCode = String(main.dropFirst("js:".count))
            selector = ""
        } else if let jsTagRange = main.range(of: "<js>", options: .caseInsensitive) {
            if let closeTagRange = main.range(of: "</js>", options: .caseInsensitive, range: jsTagRange.upperBound..<main.endIndex) {
                jsCode = String(main[jsTagRange.upperBound..<closeTagRange.lowerBound])
                let beforeTag = String(main[..<jsTagRange.lowerBound])
                let afterTag = String(main[closeTagRange.upperBound...])
                selector = (beforeTag + afterTag).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if let atJsRange = main.range(of: "@js:", options: .caseInsensitive) {
            jsCode = String(main[atJsRange.upperBound...])
            selector = String(main[..<atJsRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var template: String?
        if selector.contains("{{") {
            template = selector
        }

        return ParsedRule(
            selector: selector,
            jsCode: jsCode,
            replaceRegex: replaceRegex,
            replaceValue: replaceValue,
            template: template
        )
    }

    static func hasJS(_ rule: String) -> Bool {
        let lower = rule.lowercased()
        return lower.contains("@js:") || lower.contains("<js>") || lower.hasPrefix("js:")
    }

    static func hasTemplate(_ rule: String) -> Bool {
        return rule.contains("{{")
    }

    static func applyRegexReplace(_ text: String, regex: String, replacement: String) -> String {
        guard let regexObj = try? NSRegularExpression(pattern: regex, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regexObj.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
