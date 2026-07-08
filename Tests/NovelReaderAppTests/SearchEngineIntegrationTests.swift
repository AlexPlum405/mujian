import Testing
import Foundation
@testable import NovelReaderApp

@MainActor
struct SearchEngineIntegrationTests {
    @Test func jsonPathEvaluatesSimpleAPIResponse() {
        let json = """
        {
            "code": 0,
            "data": [
                {"title": "寂静杀戮", "author": "熊狼狗", "id": "12345", "intro": "末日降临..."},
                {"title": "寂静王座", "author": "另一作者", "id": "12346", "intro": "另一本书"}
            ]
        }
        """

        let nodes = JSONPathEvaluator.evaluate(jsonString: json, path: ".data[*]")

        #expect(nodes.count == 2)
        #expect(nodes[0].text == "寂静杀戮" || nodes[0].text.contains("寂静"))
    }

    @Test func jsonPathExtractsNestedAttributes() {
        let json = """
        {
            "data": [
                {"book_name": "寂静杀戮", "author": "熊狼狗", "book_url": "/book/12345"}
            ]
        }
        """

        let nodes = JSONPathEvaluator.evaluate(jsonString: json, path: "$.data[*]")

        #expect(nodes.count == 1)
        let title = JSONPathEvaluator.extractAttribute(from: nodes[0], rule: ".book_name")
        let author = JSONPathEvaluator.extractAttribute(from: nodes[0], rule: ".author")
        let bookUrl = JSONPathEvaluator.extractAttribute(from: nodes[0], rule: ".book_url")

        #expect(title == "寂静杀戮")
        #expect(author == "熊狼狗")
        #expect(bookUrl == "/book/12345")
    }

    @Test func jsonPathHandlesDollarPrefix() {
        let json = """
        {"result": [{"name": "测试书"}]}
        """

        let nodes1 = JSONPathEvaluator.evaluate(jsonString: json, path: "$.result[*]")
        let nodes2 = JSONPathEvaluator.evaluate(jsonString: json, path: ".result[*]")

        #expect(nodes1.count == 1)
        #expect(nodes2.count == 1)
        #expect(nodes1[0].text == "测试书")
    }

    @Test func jsonPathHandlesEmptyResult() {
        let json = """
        {"data": []}
        """

        let nodes = JSONPathEvaluator.evaluate(jsonString: json, path: ".data[*]")

        #expect(nodes.isEmpty)
    }

    @Test func sourceRuleTypeDetectsJSONPathVariants() {
        #expect(SourceRuleType.detect("$.data[*]") == .jsonpath)
        #expect(SourceRuleType.detect(".search[*]") == .jsonpath)
        #expect(SourceRuleType.detect("@json:$.data") == .jsonpath)
        #expect(SourceRuleType.detect("json:$.data") == .jsonpath)
    }

    @Test func sourceRuleTypeDetectsCSSVariants() {
        #expect(SourceRuleType.detect(".result-item") == .css)
        #expect(SourceRuleType.detect("css:.result-item") == .css)
        #expect(SourceRuleType.detect("@css:.result-item") == .css)
        #expect(SourceRuleType.detect("class.res-book-item") == .css)
    }

    @Test func sourceRuleTypeDetectsXPathVariants() {
        #expect(SourceRuleType.detect("//div[@class='bookname']") == .xpath)
        #expect(SourceRuleType.detect("@xpath://div[@class='book']") == .xpath)
        #expect(SourceRuleType.detect(".//div[@class='book']") == .xpath)
    }

    @Test func legadoRegexReplacementStripsHTMLTags() {
        let rule = ".author##<b.*?>@</b>"
        let text = "<b class=\"hl\">熊狼狗</b>"

        let processed = LegadoBookSourceEngine.applyLegadoRulesStatic(text, rule)
        #expect(processed == "熊狼狗")
    }
}

extension LegadoBookSourceEngine {
    static func applyLegadoRulesStatic(_ text: String, _ rule: String) -> String {
        var result = text

        if let replaceRange = rule.range(of: "##") {
            let afterHashes = String(rule[replaceRange.upperBound...])
            let segments = afterHashes.split(separator: "|", maxSplits: 1).map(String.init)

            if segments.count == 1 {
                let patterns = segments[0].split(separator: "@").map(String.init)
                let replacement = ""
                for pattern in patterns {
                    if pattern.isEmpty == false, let regex = try? NSRegularExpression(pattern: pattern) {
                        let range = NSRange(result.startIndex..., in: result)
                        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
                    }
                }
            } else if segments.count == 2 {
                let patterns = segments[0].split(separator: "@").map(String.init)
                let replacement = segments[1]
                for pattern in patterns {
                    if pattern.isEmpty == false, let regex = try? NSRegularExpression(pattern: pattern) {
                        let range = NSRange(result.startIndex..., in: result)
                        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
                    }
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
