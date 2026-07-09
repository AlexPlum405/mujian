import Testing
import Foundation
@testable import NovelReaderApp

@MainActor
struct JSRuleTests {
    @Test func jsBridgeBasicExecution() {
        let bridge = LegadoJSBridge()
        let result = bridge.execute(
            jsCode: "result + ' World'",
            result: "Hello",
            baseUrl: "https://example.com",
            book: nil,
            source: nil
        )
        print("\n========== JS Bridge 基础测试 ==========")
        print("输入: result='Hello'")
        print("JS: result + ' World'")
        print("输出: \(result)")
        print("========================================\n")
        #expect(result == "Hello World")
    }

    @Test func jsBridgeJavaBase64() {
        let bridge = LegadoJSBridge()
        let result = bridge.execute(
            jsCode: "java.base64Encode('hello')",
            result: "",
            baseUrl: "",
            book: nil,
            source: nil
        )
        print("\n========== Base64 编码测试 ==========")
        print("输入: 'hello'")
        print("输出: \(result)")
        print("======================================\n")
        #expect(result == "aGVsbG8=")
    }

    @Test func jsBridgeJavaPutGet() {
        let bridge = LegadoJSBridge()
        bridge.execute(
            jsCode: "java.put('myKey', 'myValue')",
            result: "",
            baseUrl: "",
            book: nil,
            source: nil
        )
        let result = bridge.execute(
            jsCode: "java.get('myKey')",
            result: "",
            baseUrl: "",
            book: nil,
            source: nil
        )
        print("\n========== Put/Get 测试 ==========")
        print("put('myKey', 'myValue')")
        print("get('myKey') = \(result)")
        print("==================================\n")
        #expect(result == "myValue")
    }

    @Test func legadoSelectorConversion() {
        print("\n========== Legado 选择器转换 ==========")

        let css1 = LegadoSelector.toCSS("class.hot_sale@tag.a.0")
        print("class.hot_sale@tag.a.0 -> \(css1)")
        #expect(css1.contains(".hot_sale"))

        let css2 = LegadoSelector.toCSS("id.chaptercontent@p")
        print("id.chaptercontent@p -> \(css2)")
        #expect(css2.contains("#chaptercontent"))

        let css3 = LegadoSelector.toCSS(".bookbox")
        print(".bookbox -> \(css3)")
        #expect(css3 == ".bookbox")

        print("========================================\n")
    }

    @Test func ruleParserJSExtraction() {
        print("\n========== 规则解析器测试 ==========")

        let rule1 = "id.content@html@js:result.replace(/ad/g, '')"
        let parsed1 = LegadoRuleParser.parse(rule1)
        print("规则: \(rule1)")
        print("  selector: \(parsed1.selector)")
        print("  jsCode: \(parsed1.jsCode ?? "nil")")
        #expect(parsed1.jsCode != nil)
        #expect(parsed1.jsCode!.contains("replace"))

        let rule2 = ".content##广告文字##"
        let parsed2 = LegadoRuleParser.parse(rule2)
        print("规则: \(rule2)")
        print("  selector: \(parsed2.selector)")
        print("  replaceRegex: \(parsed2.replaceRegex ?? "nil")")
        print("  replaceValue: \(parsed2.replaceValue ?? "nil")")
        #expect(parsed2.replaceRegex == "广告文字")

        print("====================================\n")
    }

    @Test func ruleParserRegexReplace() {
        let text = "Hello World 123"
        let result = LegadoRuleParser.applyRegexReplace(text, regex: "\\d+", replacement: "")
        print("\n========== 正则替换测试 ==========")
        print("输入: '\(text)'")
        print("正则: \\d+ 替换为空")
        print("输出: '\(result)'")
        print("===================================\n")
        #expect(result == "Hello World ")
    }
}
