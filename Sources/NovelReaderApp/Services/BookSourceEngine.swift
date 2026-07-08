import Foundation
import SwiftSoup

enum BookSourceError: LocalizedError, Equatable {
    case invalidFormat
    case sourceUnavailable
    case chapterNotFound
    case emptyContent
    case paused
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "书源文件格式不正确，无法识别。"
        case .sourceUnavailable:
            "该书源暂不可用。"
        case .chapterNotFound:
            "找不到这一章。"
        case .emptyContent:
            "这一章没有可显示的正文。"
        case .paused:
            "已暂停加载。"
        case .network(let message):
            message
        }
    }
}

struct OnlineSearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let author: String?
    let bookUrl: String
    let intro: String?
    let sourceId: String
    let sourceName: String

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String?,
        bookUrl: String,
        intro: String? = nil,
        sourceId: String,
        sourceName: String
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.bookUrl = bookUrl
        self.intro = intro
        self.sourceId = sourceId
        self.sourceName = sourceName
    }
}

struct OnlineChapter: Identifiable, Equatable {
    let id: String
    let title: String
    let url: String

    init(id: String = UUID().uuidString, title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }
}

@MainActor
protocol BookSourceEngine: AnyObject {
    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult]
    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter]
    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String
    func pause()
    func resume()
}

@MainActor
final class StubBookSourceEngine: BookSourceEngine {
    private(set) var isPaused = false
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0
    private(set) var lastSearchQuery: String?
    private(set) var lastSearchedSourceIds: [String] = []
    private(set) var lastLoadedBookUrl: String?

    var searchResults: [OnlineSearchResult] = []
    var chapters: [OnlineChapter] = []
    var content: String = "正文内容"

    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult] {
        let enabledIds = Set(sources.filter { $0.isEnabled }.map(\.id))
        lastSearchQuery = query
        lastSearchedSourceIds = Array(enabledIds)
        return searchResults.filter { enabledIds.contains($0.sourceId) }
    }

    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter] {
        lastLoadedBookUrl = bookUrl
        return chapters
    }

    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String {
        if isPaused {
            throw BookSourceError.paused
        }
        return content
    }

    func pause() {
        isPaused = true
        pauseCallCount += 1
    }

    func resume() {
        isPaused = false
        resumeCallCount += 1
    }
}

@MainActor
final class LegadoBookSourceEngine: BookSourceEngine {
    @Published private(set) var isPaused = false

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult] {
        var results: [OnlineSearchResult] = []
        for source in sources where source.isEnabled {
            if isPaused { break }
            guard let ruleType = SourceRuleType.detect(source.searchRule), ruleType != .unknown else {
                continue
            }
            do {
                let (url, option) = resolvedSearchURL(template: source.searchUrl, query: query, base: source.url)
                let data = try await fetchData(url: url, option: option)
                let parsed: [OnlineSearchResult]
                if ruleType == .jsonpath {
                    parsed = parseSearchResultsJSON(data: data, source: source)
                } else {
                    let html = EncodingDetector.decode(data: data, httpCharset: option.charset)
                    parsed = try parseSearchResults(html: html, source: source, ruleType: ruleType)
                }
                results.append(contentsOf: parsed)
            } catch {
                continue
            }
        }
        return results
    }

    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter] {
        guard isPaused == false else {
            throw BookSourceError.paused
        }
        guard let ruleType = SourceRuleType.detect(source.chapterListRule), ruleType != .unknown else {
            throw BookSourceError.sourceUnavailable
        }
        let url = resolvedURL(path: bookUrl, base: source.url)
        let html = try await fetch(url: url)
        if Task.isCancelled || isPaused {
            throw BookSourceError.paused
        }
        return try parseChapterList(html: html, source: source, ruleType: ruleType)
    }

    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String {
        guard isPaused == false else {
            throw BookSourceError.paused
        }
        guard let ruleType = SourceRuleType.detect(source.contentRule), ruleType != .unknown else {
            throw BookSourceError.sourceUnavailable
        }
        let url = resolvedURL(path: chapterUrl, base: source.url)
        let html = try await fetch(url: url)
        if Task.isCancelled || isPaused {
            throw BookSourceError.paused
        }
        let text = try parseContent(html: html, source: source, ruleType: ruleType)
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw BookSourceError.emptyContent
        }
        return text
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    private func fetchData(url: URL, option: LegadoUrlOption? = nil) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        if let option {
            if option.method == "POST" {
                request.httpMethod = "POST"
                if let body = option.body {
                    if body.contains("{") && body.contains("}") {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    } else {
                        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    }
                    request.httpBody = body.data(using: .utf8)
                }
            }
            for (key, value) in option.headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (400...499).contains(http.statusCode) {
                throw BookSourceError.sourceUnavailable
            }
            return data
        } catch let error as URLError {
            throw BookSourceError.network(Self.friendlyMessage(for: error))
        } catch {
            throw BookSourceError.network("请求失败，请稍后再试。")
        }
    }

    private func fetch(url: URL) async throws -> String {
        let data = try await fetchData(url: url)
        return EncodingDetector.decode(data: data)
    }

    private func resolvedSearchURL(template: String, query: String, base: String) -> (url: URL, option: LegadoUrlOption) {
        let (rawUrl, option) = LegadoUrlParser.parse(template, searchKey: query)
        let absolute = LegadoUrlParser.resolveURL(base: base, relative: rawUrl)
        let url = URL(string: absolute) ?? URL(string: base)!
        return (url, option)
    }

    private func resolvedURL(path: String, base: String) -> URL {
        let absolute = LegadoUrlParser.resolveURL(base: base, relative: path)
        return URL(string: absolute) ?? URL(string: base)!
    }

    private func parseSearchResults(html: String, source: BookSource, ruleType: SourceRuleType) throws -> [OnlineSearchResult] {
        var results: [OnlineSearchResult] = []

        switch ruleType {
        case .css:
            let doc = try SwiftSoup.parse(html)
            let nodes = try doc.select(source.searchRule)
            for node in nodes {
                let title = (try? extractCSS(from: node, rule: source.titleRule)) ?? ""
                if title.isEmpty { continue }
                let author = try? extractCSS(from: node, rule: source.authorRule)
                let bookUrlRule = source.bookUrlRule.isEmpty ? source.chapterUrlRule : source.bookUrlRule
                let bookUrl = try extractCSS(from: node, rule: bookUrlRule)
                let intro = try? extractCSS(from: node, rule: source.introRule)
                results.append(OnlineSearchResult(
                    title: title,
                    author: author,
                    bookUrl: resolvedURL(path: bookUrl, base: source.url).absoluteString,
                    intro: intro?.isEmpty == false ? intro : nil,
                    sourceId: source.id,
                    sourceName: source.name
                ))
            }
        case .xpath:
            let xpath = SourceRuleType.stripXPathPrefix(source.searchRule)
            let nodes = XPathEvaluator.evaluate(html: html, xpath: xpath)
            for node in nodes {
                let title = extractXPath(from: node, rule: source.titleRule)
                if title.isEmpty { continue }
                let author = extractXPath(from: node, rule: source.authorRule)
                let bookUrlRule = source.bookUrlRule.isEmpty ? source.chapterUrlRule : source.bookUrlRule
                let bookUrl = extractXPath(from: node, rule: bookUrlRule)
                let intro = extractXPath(from: node, rule: source.introRule)
                results.append(OnlineSearchResult(
                    title: title,
                    author: author,
                    bookUrl: resolvedURL(path: bookUrl, base: source.url).absoluteString,
                    intro: intro.isEmpty == false ? intro : nil,
                    sourceId: source.id,
                    sourceName: source.name
                ))
            }
        default:
            return []
        }
        return results
    }

    private func parseChapterList(html: String, source: BookSource, ruleType: SourceRuleType) throws -> [OnlineChapter] {
        var chapters: [OnlineChapter] = []

        switch ruleType {
        case .css:
            let doc = try SwiftSoup.parse(html)
            let nodes = try doc.select(source.chapterListRule)
            for node in nodes {
                let title = (try? extractCSS(from: node, rule: source.chapterTitleRule)) ?? ""
                let url = try extractCSS(from: node, rule: source.chapterUrlRule)
                guard url.isEmpty == false else { continue }
                chapters.append(OnlineChapter(
                    title: title.isEmpty ? "未命名章节" : title,
                    url: resolvedURL(path: url, base: source.url).absoluteString
                ))
            }
        case .xpath:
            let xpath = SourceRuleType.stripXPathPrefix(source.chapterListRule)
            let nodes = XPathEvaluator.evaluate(html: html, xpath: xpath)
            for node in nodes {
                let title = extractXPath(from: node, rule: source.chapterTitleRule)
                let url = extractXPath(from: node, rule: source.chapterUrlRule)
                guard url.isEmpty == false else { continue }
                chapters.append(OnlineChapter(
                    title: title.isEmpty ? "未命名章节" : title,
                    url: resolvedURL(path: url, base: source.url).absoluteString
                ))
            }
        default:
            return []
        }
        return chapters
    }

    private func parseSearchResultsJSON(data: Data, source: BookSource) -> [OnlineSearchResult] {
        let path = SourceRuleType.stripJSONPathPrefix(source.searchRule)
        let nodes = JSONPathEvaluator.evaluate(jsonData: data, path: path)

        var results: [OnlineSearchResult] = []
        for node in nodes {
            let title = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: source.titleRule), source.titleRule)
            if title.isEmpty { continue }
            let author = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: source.authorRule), source.authorRule)
            let bookUrlRule = source.bookUrlRule.isEmpty ? source.chapterUrlRule : source.bookUrlRule
            let bookUrl = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: bookUrlRule), bookUrlRule)
            let intro = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: source.introRule), source.introRule)
            results.append(OnlineSearchResult(
                title: title,
                author: author,
                bookUrl: resolvedURL(path: bookUrl, base: source.url).absoluteString,
                intro: intro.isEmpty == false ? intro : nil,
                sourceId: source.id,
                sourceName: source.name
            ))
        }
        return results
    }

    private func applyLegadoRules(_ text: String, _ rule: String) -> String {
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

    private func parseContent(html: String, source: BookSource, ruleType: SourceRuleType) throws -> String {
        switch ruleType {
        case .css:
            let doc = try SwiftSoup.parse(html)
            let nodes = try doc.select(source.contentRule)
            return try nodes.text()
        case .xpath:
            let xpath = SourceRuleType.stripXPathPrefix(source.contentRule)
            let nodes = XPathEvaluator.evaluate(html: html, xpath: xpath)
            return nodes.map(\.text).joined(separator: "\n")
        default:
            return ""
        }
    }

    private func extractCSS(from element: Element, rule: String) throws -> String {
        var trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("*") {
            trimmed = String(trimmed.dropFirst())
        }

        if let atIndex = trimmed.lastIndex(of: "@") {
            let selector = String(trimmed[..<atIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let attr = String(trimmed[trimmed.index(after: atIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

            let target: Element
            if selector.isEmpty {
                target = element
            } else if let selected = try element.select(selector).first() {
                target = selected
            } else {
                target = element
            }

            if attr.isEmpty || attr == "text" {
                return try target.text()
            }
            if attr == "html" || attr == "innerHTML" {
                return try target.html()
            }
            return try target.attr(attr)
        }

        if trimmed.isEmpty {
            return try element.text()
        }

        if let selected = try element.select(trimmed).first() {
            return try selected.text()
        }
        return try element.text()
    }

    private func extractXPath(from node: XPathNode, rule: String) -> String {
        var trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = SourceRuleType.stripXPathPrefix(trimmed)

        if trimmed.hasSuffix("@text") || trimmed.hasSuffix("/text()") {
            return node.text
        }

        if trimmed.hasSuffix("@href") {
            return node.href ?? ""
        }

        if trimmed.hasSuffix("@html") || trimmed.hasSuffix("/html()") {
            return node.html ?? ""
        }

        if trimmed.hasPrefix("@") {
            let attrName = String(trimmed.dropFirst())
            if attrName == "text" {
                return node.text
            }
            if attrName == "href" {
                return node.href ?? ""
            }
            return ""
        }

        return node.text
    }

    private static func friendlyMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            "没有网络连接，请检查网络后重试。"
        case .timedOut:
            "请求超时，请稍后再试。"
        case .cannotConnectToHost, .cannotFindHost:
            "无法连接到服务器。"
        case .cancelled:
            "已暂停加载。"
        default:
            "网络异常，请稍后再试。"
        }
    }
}

enum SourceRuleType {
    case css
    case xpath
    case jsonpath
    case unknown

    static func detect(_ rule: String?) -> SourceRuleType? {
        guard let rule, rule.isEmpty == false else { return nil }
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.hasPrefix("xpath:") || lower.hasPrefix("@xpath:") {
            return .xpath
        }
        if lower.hasPrefix("css:") || lower.hasPrefix("@css:") {
            return .css
        }
        if lower.hasPrefix("json:") || lower.hasPrefix("@json:") || lower.hasPrefix("$.") {
            return .jsonpath
        }

        if trimmed.hasPrefix("//") || trimmed.hasPrefix(".//") || trimmed.hasPrefix("(") {
            return .xpath
        }

        if trimmed.hasPrefix(".") && trimmed.contains("[") {
            return .jsonpath
        }

        if trimmed.contains("##") || trimmed.contains("@put:") {
            if trimmed.hasPrefix(".") || trimmed.hasPrefix("$") {
                return .jsonpath
            }
        }

        return .css
    }

    static func stripXPathPrefix(_ rule: String) -> String {
        var result = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.lowercased().hasPrefix("@xpath:") {
            result = String(result.dropFirst("@xpath:".count))
        } else if result.lowercased().hasPrefix("xpath:") {
            result = String(result.dropFirst("xpath:".count))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripJSONPathPrefix(_ rule: String) -> String {
        var result = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.lowercased().hasPrefix("@json:") {
            result = String(result.dropFirst("@json:".count))
        } else if result.lowercased().hasPrefix("json:") {
            result = String(result.dropFirst("json:".count))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
