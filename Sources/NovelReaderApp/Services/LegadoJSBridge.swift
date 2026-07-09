import Foundation
import JavaScriptCore
import SwiftSoup

final class LegadoJSBridge {
    private let context: JSContext
    private var variables: [String: String] = [:]
    private var currentHTML: String = ""

    private static let chromeUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    init() {
        context = JSContext()!
        context.exceptionHandler = { _, exception in
            if let exception {
                print("[LegadoJSBridge] JS error: \(exception)")
            }
        }
        installAPIs()
    }

    private func installAPIs() {
        let java = JSValue(newObjectIn: context)

        let getBlock: @convention(block) (String) -> String = { [weak self] arg in
            guard let self else { return "" }
            if arg.hasPrefix("http://") || arg.hasPrefix("https://") {
                return self.httpGet(url: arg)
            }
            return self.variables[arg] ?? ""
        }
        java?.setObject(getBlock, forKeyedSubscript: "get" as NSCopying & NSObjectProtocol)

        let ajaxBlock: @convention(block) (String) -> String = { [weak self] url in
            return self?.httpGet(url: url) ?? ""
        }
        java?.setObject(ajaxBlock, forKeyedSubscript: "ajax" as NSCopying & NSObjectProtocol)

        let postBlock: @convention(block) (String, String) -> String = { [weak self] url, body in
            return self?.httpPost(url: url, body: body) ?? ""
        }
        java?.setObject(postBlock, forKeyedSubscript: "post" as NSCopying & NSObjectProtocol)

        let getStringBlock: @convention(block) (String) -> String = { [weak self] url in
            return self?.httpGet(url: url) ?? ""
        }
        java?.setObject(getStringBlock, forKeyedSubscript: "getString" as NSCopying & NSObjectProtocol)

        let logBlock: @convention(block) (String) -> Void = { msg in
            print("[LegadoJSBridge] \(msg)")
        }
        java?.setObject(logBlock, forKeyedSubscript: "log" as NSCopying & NSObjectProtocol)

        let toastBlock: @convention(block) (String) -> Void = { _ in }
        java?.setObject(toastBlock, forKeyedSubscript: "toast" as NSCopying & NSObjectProtocol)

        let putBlock: @convention(block) (String, String) -> Void = { [weak self] key, value in
            self?.variables[key] = value
        }
        java?.setObject(putBlock, forKeyedSubscript: "put" as NSCopying & NSObjectProtocol)

        let base64EncodeBlock: @convention(block) (String) -> String = { str in
            return Data(str.utf8).base64EncodedString()
        }
        java?.setObject(base64EncodeBlock, forKeyedSubscript: "base64Encode" as NSCopying & NSObjectProtocol)

        let base64DecodeBlock: @convention(block) (String) -> String = { str in
            guard let data = Data(base64Encoded: str) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
        java?.setObject(base64DecodeBlock, forKeyedSubscript: "base64Decode" as NSCopying & NSObjectProtocol)

        let encodeURIBlock: @convention(block) (String, String) -> String = { str, _ in
            return str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? str
        }
        java?.setObject(encodeURIBlock, forKeyedSubscript: "encodeURI" as NSCopying & NSObjectProtocol)

        let getElementsBlock: @convention(block) (String, String) -> [String] = { html, selector in
            return LegadoJSBridge.extractElements(html: html, selector: selector)
        }
        java?.setObject(getElementsBlock, forKeyedSubscript: "getElements" as NSCopying & NSObjectProtocol)

        let getElementBlock: @convention(block) (String, String) -> String = { html, selector in
            return LegadoJSBridge.extractElements(html: html, selector: selector).first ?? ""
        }
        java?.setObject(getElementBlock, forKeyedSubscript: "getElement" as NSCopying & NSObjectProtocol)

        let getStringListBlock: @convention(block) (String, String) -> [String] = { html, selector in
            return LegadoJSBridge.extractElements(html: html, selector: selector)
        }
        java?.setObject(getStringListBlock, forKeyedSubscript: "getStringList" as NSCopying & NSObjectProtocol)

        let setContentBlock: @convention(block) (String) -> Void = { [weak self] html in
            self?.currentHTML = html
        }
        java?.setObject(setContentBlock, forKeyedSubscript: "setContent" as NSCopying & NSObjectProtocol)

        let toNumChapterBlock: @convention(block) (String) -> String = { str in
            return LegadoJSBridge.toNumChapter(str)
        }
        java?.setObject(toNumChapterBlock, forKeyedSubscript: "toNumChapter" as NSCopying & NSObjectProtocol)

        let getVerificationCodeBlock: @convention(block) (String) -> String = { _ in
            return ""
        }
        java?.setObject(getVerificationCodeBlock, forKeyedSubscript: "getVerificationCode" as NSCopying & NSObjectProtocol)

        let startBrowserAwaitBlock: @convention(block) (String) -> String = { _ in
            return ""
        }
        java?.setObject(startBrowserAwaitBlock, forKeyedSubscript: "startBrowserAwait" as NSCopying & NSObjectProtocol)

        let startBrowserBlock: @convention(block) (String) -> Void = { _ in }
        java?.setObject(startBrowserBlock, forKeyedSubscript: "startBrowser" as NSCopying & NSObjectProtocol)

        context.setObject(java, forKeyedSubscript: "java" as NSCopying & NSObjectProtocol)

        let cookie = JSValue(newObjectIn: context)
        let getCookieBlock: @convention(block) (String) -> String = { _ in
            return ""
        }
        cookie?.setObject(getCookieBlock, forKeyedSubscript: "getCookie" as NSCopying & NSObjectProtocol)
        let removeCookieBlock: @convention(block) (String) -> Void = { _ in }
        cookie?.setObject(removeCookieBlock, forKeyedSubscript: "removeCookie" as NSCopying & NSObjectProtocol)
        context.setObject(cookie, forKeyedSubscript: "cookie" as NSCopying & NSObjectProtocol)
    }

    func execute(jsCode: String, result: String, baseUrl: String, book: [String: Any]?, source: [String: Any]?) -> String {
        context.setObject(result, forKeyedSubscript: "result" as NSCopying & NSObjectProtocol)
        context.setObject(baseUrl, forKeyedSubscript: "baseUrl" as NSCopying & NSObjectProtocol)
        context.setObject(book ?? [:], forKeyedSubscript: "book" as NSCopying & NSObjectProtocol)

        let sourceObj = JSValue(newObjectIn: context)
        if let source {
            if let name = source["name"] as? String {
                sourceObj?.setObject(name, forKeyedSubscript: "name" as NSCopying & NSObjectProtocol)
            }
            if let bookSourceUrl = source["bookSourceUrl"] as? String {
                sourceObj?.setObject(bookSourceUrl, forKeyedSubscript: "bookSourceUrl" as NSCopying & NSObjectProtocol)
            }
        }
        let bookSourceUrl = (source?["bookSourceUrl"] as? String) ?? ""
        let getKeyBlock: @convention(block) () -> String = {
            return bookSourceUrl
        }
        sourceObj?.setObject(getKeyBlock, forKeyedSubscript: "getKey" as NSCopying & NSObjectProtocol)
        context.setObject(sourceObj, forKeyedSubscript: "source" as NSCopying & NSObjectProtocol)

        let value = context.evaluateScript(jsCode)
        if value == nil || value?.isNull == true || value?.isUndefined == true {
            return ""
        }
        if value?.isArray == true {
            if let array = value?.toArray() {
                return array.map { String(describing: $0) }.joined(separator: "\n")
            }
        }
        return value?.toString() ?? ""
    }

    func evaluateTemplate(_ template: String, result: String, baseUrl: String, book: [String: Any]?, source: [String: Any]?) -> String {
        var output = template
        while let range = output.range(of: "{{") {
            guard let endRange = output.range(of: "}}", range: range.upperBound..<output.endIndex) else {
                break
            }
            let expression = String(output[range.upperBound..<endRange.lowerBound])
            let value = execute(jsCode: expression, result: result, baseUrl: baseUrl, book: book, source: source)
            output.replaceSubrange(range.lowerBound..<endRange.upperBound, with: value)
        }
        return output
    }

    private func httpGet(url: String) -> String {
        guard let urlObj = URL(string: url) else { return "" }
        var request = URLRequest(url: urlObj, timeoutInterval: 10)
        request.setValue(LegadoJSBridge.chromeUA, forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        let box = HTTPResultBox()

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            box.data = data
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 10)

        guard let data = box.data else { return "" }
        return EncodingDetector.decode(data: data)
    }

    private func httpPost(url: String, body: String) -> String {
        guard let urlObj = URL(string: url) else { return "" }
        var request = URLRequest(url: urlObj, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue(LegadoJSBridge.chromeUA, forHTTPHeaderField: "User-Agent")

        if body.contains("{") && body.contains("}") {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body.data(using: .utf8)

        let semaphore = DispatchSemaphore(value: 0)
        let box = HTTPResultBox()

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            box.data = data
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 10)

        guard let data = box.data else { return "" }
        return EncodingDetector.decode(data: data)
    }

    private static func extractElements(html: String, selector: String) -> [String] {
        do {
            let doc = try SwiftSoup.parse(html)
            let elements = try doc.select(selector)
            return elements.array().compactMap { try? $0.text() }
        } catch {
            return []
        }
    }

    private static func toNumChapter(_ str: String) -> String {
        let pattern = "[0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return str }
        let searchRange = NSRange(str.startIndex..., in: str)
        if let match = regex.firstMatch(in: str, range: searchRange),
           let matchRange = Range(match.range, in: str) {
            return String(str[matchRange])
        }
        return str
    }
}

private final class HTTPResultBox: @unchecked Sendable {
    var data: Data?
}
